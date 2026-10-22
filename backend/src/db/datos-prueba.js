// Carga los datos de prueba usados en el informe de pruebas del MVP: 7 asignaturas,
// 2 estudiantes y 5 materiales en PDF (2 anónimos, uno con valoración de 5 estrellas).
// No borra nada: lo que ya existe (mismo código de asignatura, correo o título) se
// deja como está, así que se puede ejecutar varias veces.
//
// Uso: npm run datos-prueba
const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');
const { pool } = require('../config/db');
const { uploadsDir } = require('../middleware/upload');

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
  { titulo: 'Parcial 1 – Límites y continuidad', descripcion: 'Primer parcial con límites, continuidad y sus soluciones.', codigo: 'MAT101', profesor: 'Martínez', periodo: '2026-1', anonimo: false },
  { titulo: 'Taller de derivadas resuelto', descripcion: 'Taller de reglas de derivación con el procedimiento completo.', codigo: 'MAT101', profesor: 'Martínez', periodo: '2025-2', anonimo: true },
  { titulo: 'Parcial final de Programación I', descripcion: 'Parcial final con ejercicios de ciclos, funciones y arreglos.', codigo: 'SIS102', profesor: 'Gómez', periodo: '2026-1', anonimo: false },
  { titulo: 'Quiz de cinemática', descripcion: 'Quiz corto de movimiento rectilíneo uniforme y acelerado.', codigo: 'FIS201', profesor: 'Rodríguez', periodo: '2025-2', anonimo: true },
  { titulo: 'Ejercicios de SQL con solución', descripcion: 'Consultas SELECT, JOIN y GROUP BY resueltas paso a paso.', codigo: 'SIS401', profesor: null, periodo: '2026-1', anonimo: false },
];

const VALORACION = {
  titulo: 'Ejercicios de SQL con solución',
  correo: 'estudiante2@prueba.com',
  puntuacion: 5,
  comentario: 'Las soluciones están bien explicadas.',
};

// PDF mínimo de una página con el título del material.
function crearPdf(texto) {
  const seguro = texto.normalize('NFD').replace(/[^\x20-\x7e]/g, '').replace(/[()\\]/g, '');
  const contenido = `BT /F1 20 Tf 72 720 Td (${seguro}) Tj ET`;
  const objetos = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>',
    `<< /Length ${contenido.length} >>\nstream\n${contenido}\nendstream`,
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  ];
  let pdf = '%PDF-1.4\n';
  const posiciones = objetos.map((obj, i) => {
    const pos = pdf.length;
    pdf += `${i + 1} 0 obj\n${obj}\nendobj\n`;
    return pos;
  });
  const xref = pdf.length;
  pdf += `xref\n0 ${objetos.length + 1}\n0000000000 65535 f \n`;
  pdf += posiciones.map((p) => `${String(p).padStart(10, '0')} 00000 n \n`).join('');
  pdf += `trailer\n<< /Size ${objetos.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF\n`;
  return Buffer.from(pdf, 'latin1');
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
    for (const [i, m] of MATERIALES.entries()) {
      const existe = await pool.query('SELECT 1 FROM materiales WHERE titulo = $1', [m.titulo]);
      if (existe.rows[0]) continue;

      const archivo = `datos-prueba-${i + 1}.pdf`;
      fs.writeFileSync(path.join(uploadsDir, archivo), crearPdf(m.titulo));
      // Un minuto entre materiales para que la lista salga en el mismo orden que en el informe.
      const minutosAtras = MATERIALES.length - i;
      await pool.query(
        `INSERT INTO materiales (titulo, descripcion, archivo_url, profesor, periodo_academico,
                                 es_anonimo, asignatura_id, usuario_id, fecha_publicacion, creado_en)
         SELECT $1, $2, $3, $4, $5, $6, a.id, $7,
                now() - make_interval(mins => $8), now() - make_interval(mins => $8)
           FROM asignaturas a WHERE a.codigo = $9`,
        [m.titulo, m.descripcion, `/uploads/${archivo}`, m.profesor, m.periodo, m.anonimo,
          autor.rows[0].id, minutosAtras, m.codigo]
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

    console.log(`Datos de prueba listos: ${ASIGNATURAS.length} asignaturas, ${ESTUDIANTES.length} estudiantes, ${creados} materiales nuevos.`);
    console.log(`Estudiantes: ${ESTUDIANTES.map((e) => e.correo).join(', ')} (contraseña: ${CONTRASENA_ESTUDIANTES})`);
  } catch (err) {
    console.error('Error cargando los datos de prueba:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

cargarDatos();
