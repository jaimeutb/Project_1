const { pool } = require('../config/db');
const tutor = require('../services/tutorIa');

// R-13: cada estudiante tiene un número máximo de consultas a la IA por hora,
// para controlar el costo de la API. Las respuestas que salen de la caché no
// cuentan. El conteo vive en memoria: se reinicia si el servidor se reinicia.
const LIMITE_POR_HORA = Number(process.env.IA_LIMITE_POR_HORA) || 20;
const UNA_HORA = 60 * 60 * 1000;
const consultasPorUsuario = new Map();

function registrarConsulta(usuarioId) {
  const ahora = Date.now();
  const recientes = (consultasPorUsuario.get(usuarioId) || []).filter((t) => ahora - t < UNA_HORA);
  if (recientes.length >= LIMITE_POR_HORA) {
    const minutos = Math.ceil((UNA_HORA - (ahora - recientes[0])) / 60000);
    throw new tutor.ErrorIa(429,
      `Alcanzó el límite de ${LIMITE_POR_HORA} consultas al Tutor IA por hora. Intente de nuevo en ${minutos} min.`);
  }
  recientes.push(ahora);
  consultasPorUsuario.set(usuarioId, recientes);
}

/** El material, con las mismas reglas de visibilidad de RF-05 (el retirado solo lo ve el administrador). */
async function materialVisible(req) {
  const { rows } = await pool.query(
    `SELECT m.id, m.titulo, m.descripcion, m.archivo_url, m.profesor, m.periodo_academico, m.estado,
            a.nombre AS asignatura_nombre, a.codigo AS asignatura_codigo, a.semestre AS asignatura_semestre
     FROM materiales m JOIN asignaturas a ON a.id = m.asignatura_id
     WHERE m.id = $1`,
    [req.params.material_id],
  );
  const material = rows[0];
  if (!material || (material.estado === 'retirado' && req.usuario.rol !== 'administrador')) {
    throw new tutor.ErrorIa(404, 'Material no encontrado.');
  }
  return material;
}

function responderError(err, res, next) {
  if (err instanceof tutor.ErrorIa) return res.status(err.status).json({ error: err.message });
  return next(err);
}

/** Indica a la aplicación si el Tutor IA está configurado, para mostrarlo o no. */
function estado(req, res) {
  res.json({ disponible: tutor.disponible(), modelo: tutor.modeloActivo(), limite_por_hora: LIMITE_POR_HORA });
}

/**
 * RF-14 y RF-15 comparten el mismo flujo: la primera respuesta generada para un
 * material se guarda (R-10) y se reutiliza para todos los estudiantes, salvo que
 * se pida una nueva con { "nueva": true }.
 */
function contenidoGuardado(tipo, generar) {
  return async (req, res, next) => {
    try {
      const material = await materialVisible(req);
      if (req.body?.nueva !== true) {
        const { rows } = await pool.query(
          'SELECT contenido, fuente, creado_en FROM ia_contenidos WHERE material_id = $1 AND tipo = $2',
          [material.id, tipo],
        );
        if (rows[0]) return res.json({ ...rows[0], guardado: true });
      }

      tutor.verificarConfiguracion();
      registrarConsulta(req.usuario.id);
      const { contenido, fuente } = await generar(material);
      const { rows } = await pool.query(
        `INSERT INTO ia_contenidos (material_id, tipo, contenido, fuente, modelo)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (material_id, tipo) DO UPDATE
           SET contenido = EXCLUDED.contenido, fuente = EXCLUDED.fuente,
               modelo = EXCLUDED.modelo, creado_en = now()
         RETURNING contenido, fuente, creado_en`,
        [material.id, tipo, contenido, fuente, tutor.modeloActivo()],
      );
      return res.status(201).json({ ...rows[0], guardado: false });
    } catch (err) {
      return responderError(err, res, next);
    }
  };
}

const explicacion = contenidoGuardado('explicacion', (m) => tutor.explicar(m));
const practica = contenidoGuardado('practica', (m) => tutor.practicar(m));

const MAX_PREGUNTA = 2000;
const MAX_TURNOS = 20;

/** RF-16: el estudiante le pregunta al tutor sobre el material. */
async function preguntar(req, res, next) {
  try {
    const pregunta = typeof req.body?.pregunta === 'string' ? req.body.pregunta.trim() : '';
    const historial = req.body?.historial ?? [];
    if (!pregunta) return res.status(400).json({ error: 'Escriba una pregunta.' });
    if (pregunta.length > MAX_PREGUNTA) {
      return res.status(400).json({ error: `La pregunta no puede pasar de ${MAX_PREGUNTA} caracteres.` });
    }
    const historialValido = Array.isArray(historial) && historial.every((t) => t
      && ['estudiante', 'tutor'].includes(t.rol) && typeof t.texto === 'string' && t.texto.trim());
    if (!historialValido) {
      return res.status(400).json({ error: 'El historial de la conversación no es válido.' });
    }

    const material = await materialVisible(req);
    tutor.verificarConfiguracion();
    registrarConsulta(req.usuario.id);
    // Solo se envían los últimos turnos, para acotar el costo de cada pregunta.
    const resultado = await tutor.preguntar(material, historial.slice(-MAX_TURNOS), pregunta);
    return res.json(resultado);
  } catch (err) {
    return responderError(err, res, next);
  }
}

/** Solo para las pruebas: reinicia el conteo del límite por hora. */
function reiniciarLimites() {
  consultasPorUsuario.clear();
}

/**
 * RF-18: simulacro de parcial de una asignatura, con preguntas basadas en su
 * material publicado. No se guarda: cada simulacro es distinto y cuenta para el
 * límite por hora (R-13).
 */
async function simulacro(req, res, next) {
  try {
    const { rows: asignaturas } = await pool.query(
      'SELECT * FROM asignaturas WHERE id = $1 AND activo', [req.params.asignatura_id],
    );
    const asignatura = asignaturas[0];
    if (!asignatura) return res.status(404).json({ error: 'Asignatura no encontrada.' });
    const { rows: materiales } = await pool.query(
      `SELECT titulo, descripcion, archivo_url FROM materiales
       WHERE asignatura_id = $1 AND estado = 'publicado'
       ORDER BY fecha_publicacion DESC LIMIT 5`,
      [asignatura.id],
    );
    if (!materiales.length) {
      return res.status(409).json({
        error: 'Esta asignatura todavía no tiene material publicado para armar un simulacro.',
      });
    }
    const pedidas = Number(req.body?.preguntas);
    const numero = [5, 10, 15].includes(pedidas) ? pedidas : 10;

    tutor.verificarConfiguracion();
    registrarConsulta(req.usuario.id);
    const resultado = await tutor.simulacro(asignatura, materiales, numero);
    return res.json({ asignatura: { id: asignatura.id, nombre: asignatura.nombre }, ...resultado });
  } catch (err) {
    return responderError(err, res, next);
  }
}

module.exports = {
  estado, explicacion, practica, preguntar, simulacro, reiniciarLimites, LIMITE_POR_HORA,
};
