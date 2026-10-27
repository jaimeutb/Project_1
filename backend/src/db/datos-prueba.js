// Carga los datos de prueba usados en el informe de pruebas del MVP: 7 asignaturas,
// 2 estudiantes y 5 materiales en PDF (2 anónimos, uno con valoración de 5 estrellas).
// Los PDF tienen ejercicios reales con solución (src/db/material-de-prueba/, generados
// con docs/material-de-prueba/generar.py), para que el Tutor IA tenga qué explicar.
// No borra nada: lo que ya existe (mismo código de asignatura, correo o título) se
// deja como está, así que se puede ejecutar varias veces. A los materiales de prueba
// cargados con una versión anterior (un PDF de una línea) se les cambia el archivo.
//
// Uso: npm run datos-prueba
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { pool } = require('../config/db');
const { uploadsDir } = require('../middleware/upload');
const { crearMiniatura } = require('../services/miniaturas');
const tutor = require('../services/tutorIa');

const CARPETA_PDF = path.join(__dirname, 'material-de-prueba');

const ASIGNATURAS = [
  { nombre: 'Bases de Datos', codigo: 'SIS401', semestre: '4' },
  { nombre: 'Cálculo Diferencial', codigo: 'MAT101', semestre: '1' },
  { nombre: 'Cálculo Integral', codigo: 'MAT102', semestre: '2' },
  { nombre: 'Estructuras de Datos', codigo: 'SIS203', semestre: '2' },
  { nombre: 'Física Mecánica', codigo: 'FIS201', semestre: '2' },
  { nombre: 'Ingeniería de Software', codigo: 'SIS601', semestre: '6' },
  { nombre: 'Programación I', codigo: 'SIS102', semestre: '1' },
];

const CONTRASENA_ESTUDIANTES = 'Estudiante123';
const ESTUDIANTES = [
  { nombre: '001', correo: 'estudiante@prueba.com' },
  { nombre: '002', correo: 'estudiante2@prueba.com' },
];

// En orden de publicación: el último aparece primero en la lista.
const MATERIALES = [
  { titulo: 'Parcial 1 – Límites y continuidad', pdf: 'parcial-limites.pdf', descripcion: 'Primer parcial con límites, continuidad y sus soluciones.', codigo: 'MAT101', profesor: 'Martínez', periodo: '2026-1', anonimo: false },
  { titulo: 'Taller de derivadas resuelto', pdf: 'taller-derivadas.pdf', descripcion: 'Taller de reglas de derivación con el procedimiento completo.', codigo: 'MAT101', profesor: 'Martínez', periodo: '2025-2', anonimo: true },
  { titulo: 'Parcial final de Programación I', pdf: 'parcial-programacion.pdf', descripcion: 'Parcial final con ejercicios de ciclos, funciones y arreglos.', codigo: 'SIS102', profesor: 'Gómez', periodo: '2026-1', anonimo: false },
  { titulo: 'Quiz de cinemática', pdf: 'quiz-cinematica.pdf', descripcion: 'Quiz corto de movimiento rectilíneo uniforme y acelerado.', codigo: 'FIS201', profesor: 'Rodríguez', periodo: '2025-2', anonimo: true },
  { titulo: 'Ejercicios de SQL con solución', pdf: 'ejercicios-sql.pdf', descripcion: 'Consultas SELECT, JOIN y GROUP BY resueltas paso a paso.', codigo: 'SIS401', profesor: null, periodo: '2026-1', anonimo: false },
];

const VALORACION = {
  titulo: 'Ejercicios de SQL con solución',
  correo: 'estudiante2@prueba.com',
  puntuacion: 5,
  comentario: 'Las soluciones están bien explicadas.',
};

/** Copia el PDF de prueba a UPLOADS_DIR y crea su vista previa (RF-19). */
async function copiarPdf(m, nombre) {
  const destino = path.join(uploadsDir, nombre);
  fs.copyFileSync(path.join(CARPETA_PDF, m.pdf), destino);
  return crearMiniatura(destino);
}

async function cargarDatos() {
  try {
    for (const a of ASIGNATURAS) {
      await pool.query(
        `INSERT INTO asignaturas (nombre, codigo, semestre) VALUES ($1, $2, $3)
         ON CONFLICT (codigo) DO NOTHING`,
        [a.nombre, a.codigo, a.semestre]
      );
    }

    const hash = await bcrypt.hash(CONTRASENA_ESTUDIANTES, 10);
    for (const e of ESTUDIANTES) {
      await pool.query(
        `INSERT INTO usuarios (nombre, correo, contrasena_hash) VALUES ($1, $2, $3)
         ON CONFLICT (correo) DO NOTHING`,
        [e.nombre, e.correo, hash]
      );
    }
    const autor = await pool.query('SELECT id FROM usuarios WHERE correo = $1', [ESTUDIANTES[0].correo]);

    let creados = 0;
    let actualizados = 0;
    for (const [i, m] of MATERIALES.entries()) {
      const archivo = `datos-prueba-${i + 1}.pdf`;
      const existe = await pool.query('SELECT id, archivo_url, miniatura_url FROM materiales WHERE titulo = $1', [m.titulo]);
      if (existe.rows[0]) {
        // Material de prueba de una versión anterior: se cambia su PDF por el de ejercicios.
        const previo = existe.rows[0];
        if (previo.archivo_url === `/uploads/${archivo}` && !previo.miniatura_url) {
          const miniatura = await copiarPdf(m, archivo);
          await pool.query('UPDATE materiales SET miniatura_url = $1 WHERE id = $2', [miniatura, previo.id]);
          actualizados += 1;
        }
        continue;
      }

      const miniatura = await copiarPdf(m, archivo);
      // Un minuto entre materiales para que la lista salga en el mismo orden que en el informe.
      const minutosAtras = MATERIALES.length - i;
      await pool.query(
        `INSERT INTO materiales (titulo, descripcion, archivo_url, profesor, periodo_academico,
                                 es_anonimo, asignatura_id, usuario_id, fecha_publicacion, creado_en,
                                 miniatura_url)
         SELECT $1, $2, $3, $4, $5, $6, a.id, $7,
                now() - make_interval(mins => $8), now() - make_interval(mins => $8), $10
           FROM asignaturas a WHERE a.codigo = $9`,
        [m.titulo, m.descripcion, `/uploads/${archivo}`, m.profesor, m.periodo, m.anonimo,
          autor.rows[0].id, minutosAtras, m.codigo, miniatura]
      );
      creados += 1;
    }

    await pool.query(
      `INSERT INTO valoraciones (puntuacion, comentario, material_id, usuario_id)
       SELECT $1, $2, m.id, u.id FROM materiales m, usuarios u
        WHERE m.titulo = $3 AND u.correo = $4
       ON CONFLICT (material_id, usuario_id) DO NOTHING`,
      [VALORACION.puntuacion, VALORACION.comentario, VALORACION.titulo, VALORACION.correo]
    );

    // RF-17: si hay IA configurada, revisa los materiales de prueba que no tienen revisión.
    let revisados = 0;
    if (tutor.disponible()) {
      const { rows: pendientes } = await pool.query(
        `SELECT m.id, m.titulo, m.descripcion, m.archivo_url, m.profesor, m.periodo_academico,
                a.nombre AS asignatura_nombre, a.codigo AS asignatura_codigo, a.semestre AS asignatura_semestre
         FROM materiales m JOIN asignaturas a ON a.id = m.asignatura_id
         WHERE m.revision_ia IS NULL AND m.titulo = ANY($1)`,
        [MATERIALES.map((m) => m.titulo)]
      );
      for (const m of pendientes) {
        try {
          const revision = await tutor.revisarMaterial(m, path.join(uploadsDir, path.basename(m.archivo_url)));
          await pool.query('UPDATE materiales SET revision_ia = $1 WHERE id = $2', [
            { ...revision, modelo: tutor.modeloActivo(), revisado_en: new Date().toISOString() }, m.id]);
          revisados += 1;
          if (revision.veredicto !== 'aprobado') {
            console.warn(`La IA marcó «${m.titulo}» como ${revision.veredicto}: ${revision.motivo}`);
          }
        } catch (err) {
          console.warn(`No se pudo revisar «${m.titulo}» con la IA: ${err.message}`);
        }
      }
    }

    console.log(`Datos de prueba listos: ${ASIGNATURAS.length} asignaturas, ${ESTUDIANTES.length} estudiantes, ${creados} materiales nuevos, ${actualizados} con PDF actualizado, ${revisados} revisados por la IA.`);
    console.log(`Estudiantes: ${ESTUDIANTES.map((e) => e.correo).join(', ')} (contraseña: ${CONTRASENA_ESTUDIANTES})`);
  } catch (err) {
    console.error('Error cargando los datos de prueba:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

cargarDatos();
