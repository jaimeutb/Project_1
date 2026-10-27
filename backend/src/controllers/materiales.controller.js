const fs = require('fs');
const path = require('path');
const { pool } = require('../config/db');
const { uploadsDir } = require('../middleware/upload');
const { agregarCondicionesDeTexto } = require('../utils/busqueda');
const tutor = require('../services/tutorIa');
const { crearMiniatura } = require('../services/miniaturas');

// Selecciona los campos de material y calcula la calificación promedio (RF-08)
// y la cantidad de reportes pendientes (RNF-05: confiabilidad visible).
// RF-07: si es_anonimo = true, el nombre del autor no se expone en la respuesta.
const SELECT_MATERIAL = `
  SELECT
    m.id, m.titulo, m.descripcion, m.archivo_url, m.fecha_publicacion,
    m.profesor, m.periodo_academico, m.es_anonimo, m.estado, m.miniatura_url, m.revision_ia,
    m.asignatura_id, a.nombre AS asignatura_nombre, a.codigo AS asignatura_codigo,
    a.semestre AS asignatura_semestre,
    (m.usuario_id = $USUARIO) AS es_mio,
    CASE WHEN m.es_anonimo THEN NULL ELSE u.nombre END AS autor_nombre,
    COALESCE(ROUND(AVG(v.puntuacion)::numeric, 2), 0) AS calificacion_promedio,
    COUNT(DISTINCT v.id) AS total_valoraciones,
    COUNT(DISTINCT r.id) FILTER (WHERE r.estado = 'pendiente') AS reportes_pendientes
  FROM materiales m
  JOIN asignaturas a ON a.id = m.asignatura_id
  JOIN usuarios u ON u.id = m.usuario_id
  LEFT JOIN valoraciones v ON v.material_id = m.id
  LEFT JOIN reportes r ON r.material_id = m.id
`;
const GROUP_BY = `
  GROUP BY m.id, a.nombre, a.codigo, a.semestre, u.nombre
`;
// es_mio compara con el usuario autenticado, que va en el parámetro indicado.
const seleccion = (parametroUsuario) => SELECT_MATERIAL.replace('$USUARIO', parametroUsuario);

/**
 * RF-03/RF-04: búsqueda de material por asignatura, con filtro opcional por
 * semestre, tema (texto libre en título, descripción, nombre o código de la
 * asignatura; sin distinguir tildes) y estado.
 */
async function listar(req, res, next) {
  try {
    const { asignatura_id, semestre, q, estado, mios, tipo } = req.query;
    const condiciones = [];
    const valores = [req.usuario.id]; // $1: usuario autenticado (columna es_mio)

    if (asignatura_id) {
      valores.push(asignatura_id);
      condiciones.push(`m.asignatura_id = $${valores.length}`);
    }
    if (semestre) {
      valores.push(semestre);
      condiciones.push(`a.semestre = $${valores.length}`);
    }
    if (q) {
      agregarCondicionesDeTexto(q, condiciones, valores);
    }
    if (estado) {
      valores.push(estado);
      condiciones.push(`m.estado = $${valores.length}`);
    }
    // «Mis aportes»: el material que subió el usuario, con el resultado de su revisión.
    if (mios === 'true') condiciones.push('m.usuario_id = $1');
    // Tipo de material que identificó la IA (parcial, quiz, taller...).
    if (tipo) {
      valores.push(tipo);
      condiciones.push(`m.revision_ia->>'tipo' = $${valores.length}`);
    }
    // El material retirado solo lo ve el administrador (RF-12), para poder
    // revisarlo o volver a publicarlo. El reportado/en revisión sí se muestra a
    // los estudiantes, con su indicador (RNF-05).
    // El material pendiente de revisión (RF-17) solo lo ven su autor y el administrador.
    if (req.usuario.rol !== 'administrador') {
      condiciones.push(`m.estado != 'retirado'`);
      condiciones.push(`(m.estado != 'pendiente' OR m.usuario_id = $1)`);
    }

    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : '';
    const { rows } = await pool.query(
      `${seleccion('$1')} ${where} ${GROUP_BY} ORDER BY m.fecha_publicacion DESC`,
      valores
    );
    return res.json(rows);
  } catch (err) {
    return next(err);
  }
}

/** RF-05: visualizar la información detallada de un material. */
async function obtener(req, res, next) {
  try {
    const { id } = req.params;
    const { rows } = await pool.query(`${seleccion('$2')} WHERE m.id = $1 ${GROUP_BY}`, [id, req.usuario.id]);
    const material = rows[0];
    const oculto = material && req.usuario.rol !== 'administrador'
      && (material.estado === 'retirado' || (material.estado === 'pendiente' && !material.es_mio));
    if (!material || oculto) {
      return res.status(404).json({ error: 'Material no encontrado.' });
    }
    return res.json(material);
  } catch (err) {
    return next(err);
  }
}

/**
 * RF-06/RF-07/RF-11/RF-12: un estudiante sube su propio material (opcionalmente
 * anónimo) o un administrador carga material oficial. El archivo llega vía multer
 * (req.file) y se guarda en UPLOADS_DIR; aquí solo se registra su ruta pública.
 *
 * RF-17: antes de publicarlo, la IA lo revisa. Si lo rechaza, el archivo se borra
 * y se responde 422 con el motivo; si tiene dudas, queda «pendiente» para el
 * administrador. Sin IA configurada se publica directamente, como antes.
 * RF-19: se crea la vista previa (primera página del PDF o la imagen).
 */
async function crear(req, res, next) {
  // multer ya guardó el archivo en disco: si la carga se rechaza, se elimina
  // para no dejar archivos huérfanos en UPLOADS_DIR.
  const rechazar = (status, cuerpo) => {
    if (req.file) fs.unlink(req.file.path, () => {});
    return res.status(status).json(typeof cuerpo === 'string' ? { error: cuerpo } : cuerpo);
  };

  try {
    const { titulo, descripcion, asignatura_id, profesor, periodo_academico, es_anonimo } = req.body;

    if (!titulo || !asignatura_id) {
      return rechazar(400, 'titulo y asignatura_id son obligatorios.');
    }
    if (!req.file) {
      return rechazar(400, 'Debe adjuntar un archivo (campo "archivo").');
    }
    const asignatura = await pool.query('SELECT * FROM asignaturas WHERE id = $1', [asignatura_id]);
    if (!asignatura.rows[0] || !asignatura.rows[0].activo) {
      return rechazar(400, 'La asignatura no existe o está desactivada.');
    }

    let revision = null;
    let estado = 'publicado';
    if (tutor.disponible()) {
      const a = asignatura.rows[0];
      try {
        revision = await tutor.revisarMaterial({
          titulo, descripcion, profesor, periodo_academico,
          asignatura_nombre: a.nombre, asignatura_codigo: a.codigo, asignatura_semestre: a.semestre,
        }, req.file.path);
      } catch (err) {
        if (!(err instanceof tutor.ErrorIa)) throw err;
        // Si la IA no responde, el material no se pierde: lo revisa un administrador.
        revision = {
          veredicto: 'dudoso',
          motivo: `La IA no pudo revisarlo en este momento (${err.message}) Un administrador lo revisará.`,
          tipo: 'otro', temas: [], dificultad: null, resumen: null, criterios: null,
        };
      }
      revision = { ...revision, modelo: tutor.modeloActivo(), revisado_en: new Date().toISOString() };
      if (revision.veredicto === 'rechazado') {
        return rechazar(422, { error: `La IA no aprobó el material: ${revision.motivo}`, revision });
      }
      if (revision.veredicto === 'dudoso') estado = 'pendiente';
    }

    const miniatura = await crearMiniatura(req.file.path);
    const archivoUrl = `/uploads/${req.file.filename}`;
    const esAnonimo = es_anonimo === 'true' || es_anonimo === true;

    const { rows } = await pool.query(
      `INSERT INTO materiales
         (titulo, descripcion, archivo_url, profesor, periodo_academico, es_anonimo,
          asignatura_id, usuario_id, estado, miniatura_url, revision_ia)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING *`,
      [titulo, descripcion || null, archivoUrl, profesor || null, periodo_academico || null,
        esAnonimo, asignatura_id, req.usuario.id, estado, miniatura, revision]
    );
    return res.status(201).json(rows[0]);
  } catch (err) {
    if (req.file) fs.unlink(req.file.path, () => {});
    return next(err);
  }
}

/** RF-12: el administrador edita un material (p. ej. corrige metadatos o cambia su estado). */
async function actualizar(req, res, next) {
  try {
    const { id } = req.params;
    const { titulo, descripcion, profesor, periodo_academico, estado } = req.body;
    if (titulo !== undefined && !String(titulo).trim()) {
      return res.status(400).json({ error: 'titulo no puede quedar vacío.' });
    }

    // Los campos no enviados se conservan; un campo opcional enviado vacío ("")
    // se borra (NULL), p. ej. cuando el administrador quita el profesor.
    const { rows } = await pool.query(
      `UPDATE materiales SET
         titulo = COALESCE($1, titulo),
         descripcion = CASE WHEN $2::text IS NULL THEN descripcion ELSE NULLIF($2, '') END,
         profesor = CASE WHEN $3::text IS NULL THEN profesor ELSE NULLIF($3, '') END,
         periodo_academico = CASE WHEN $4::text IS NULL THEN periodo_academico ELSE NULLIF($4, '') END,
         estado = COALESCE($5, estado)
       WHERE id = $6
       RETURNING *`,
      [titulo, descripcion, profesor, periodo_academico, estado, id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Material no encontrado.' });
    return res.json(rows[0]);
  } catch (err) {
    return next(err);
  }
}

/** RF-12: el administrador elimina un material. */
async function eliminar(req, res, next) {
  try {
    const { id } = req.params;
    const { rows } = await pool.query(
      'DELETE FROM materiales WHERE id = $1 RETURNING archivo_url, miniatura_url', [id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Material no encontrado.' });
    // También se borra el archivo físico ("/uploads/<nombre>").
    fs.unlink(path.join(uploadsDir, path.basename(rows[0].archivo_url)), () => {});
    if (rows[0].miniatura_url) {
      fs.unlink(path.join(uploadsDir, path.basename(rows[0].miniatura_url)), () => {});
    }
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

module.exports = { listar, obtener, crear, actualizar, eliminar };
