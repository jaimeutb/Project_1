const fs = require('fs');
const path = require('path');
const { pool } = require('../config/db');
const { uploadsDir } = require('../middleware/upload');

// Selecciona los campos de material y calcula la calificación promedio (RF-08)
// y la cantidad de reportes pendientes (RNF-05: confiabilidad visible).
// RF-07: si es_anonimo = true, el nombre del autor no se expone en la respuesta.
const SELECT_MATERIAL = `
  SELECT
    m.id, m.titulo, m.descripcion, m.archivo_url, m.fecha_publicacion,
    m.profesor, m.periodo_academico, m.es_anonimo, m.estado,
    m.asignatura_id, a.nombre AS asignatura_nombre, a.semestre AS asignatura_semestre,
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
  GROUP BY m.id, a.nombre, a.semestre, u.nombre
`;

/**
 * RF-03/RF-04: búsqueda de material por asignatura, con filtro opcional por
 * semestre, tema (texto libre en título/descripción) y estado.
 */
async function listar(req, res, next) {
  try {
    const { asignatura_id, semestre, q, estado } = req.query;
    const condiciones = [];
    const valores = [];

    if (asignatura_id) {
      valores.push(asignatura_id);
      condiciones.push(`m.asignatura_id = $${valores.length}`);
    }
    if (semestre) {
      valores.push(semestre);
      condiciones.push(`a.semestre = $${valores.length}`);
    }
    if (q) {
      valores.push(`%${q}%`);
      condiciones.push(`(m.titulo ILIKE $${valores.length} OR m.descripcion ILIKE $${valores.length})`);
    }
    if (estado) {
      valores.push(estado);
      condiciones.push(`m.estado = $${valores.length}`);
    }
    // El material retirado solo lo ve el administrador (RF-12), para poder
    // revisarlo o volver a publicarlo. El reportado/en revisión sí se muestra a
    // los estudiantes, con su indicador (RNF-05).
    if (req.usuario.rol !== 'administrador') {
      condiciones.push(`m.estado != 'retirado'`);
    }

    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : '';
    const { rows } = await pool.query(
      `${SELECT_MATERIAL} ${where} ${GROUP_BY} ORDER BY m.fecha_publicacion DESC`,
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
    const { rows } = await pool.query(`${SELECT_MATERIAL} WHERE m.id = $1 ${GROUP_BY}`, [id]);
    const material = rows[0];
    if (!material || (material.estado === 'retirado' && req.usuario.rol !== 'administrador')) {
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
 */
async function crear(req, res, next) {
  // multer ya guardó el archivo en disco: si la carga se rechaza, se elimina
  // para no dejar archivos huérfanos en UPLOADS_DIR.
  const rechazar = (status, error) => {
    if (req.file) fs.unlink(req.file.path, () => {});
    return res.status(status).json({ error });
  };

  try {
    const { titulo, descripcion, asignatura_id, profesor, periodo_academico, es_anonimo } = req.body;

    if (!titulo || !asignatura_id) {
      return rechazar(400, 'titulo y asignatura_id son obligatorios.');
    }
    if (!req.file) {
      return rechazar(400, 'Debe adjuntar un archivo (campo "archivo").');
    }
    const asignatura = await pool.query('SELECT activo FROM asignaturas WHERE id = $1', [asignatura_id]);
    if (!asignatura.rows[0] || !asignatura.rows[0].activo) {
      return rechazar(400, 'La asignatura no existe o está desactivada.');
    }

    const archivoUrl = `/uploads/${req.file.filename}`;
    const esAnonimo = es_anonimo === 'true' || es_anonimo === true;

    const { rows } = await pool.query(
      `INSERT INTO materiales
         (titulo, descripcion, archivo_url, profesor, periodo_academico, es_anonimo,
          asignatura_id, usuario_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [titulo, descripcion || null, archivoUrl, profesor || null, periodo_academico || null,
        esAnonimo, asignatura_id, req.usuario.id]
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
      'DELETE FROM materiales WHERE id = $1 RETURNING archivo_url', [id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Material no encontrado.' });
    // También se borra el archivo físico ("/uploads/<nombre>").
    fs.unlink(path.join(uploadsDir, path.basename(rows[0].archivo_url)), () => {});
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

module.exports = { listar, obtener, crear, actualizar, eliminar };
