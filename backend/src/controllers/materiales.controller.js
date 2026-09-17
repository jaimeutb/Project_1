const { pool } = require('../config/db');

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
    } else {
      // Por defecto solo se muestra material publicado a los estudiantes.
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
    if (!rows[0]) return res.status(404).json({ error: 'Material no encontrado.' });
    return res.json(rows[0]);
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
  try {
    const { titulo, descripcion, asignatura_id, profesor, periodo_academico, es_anonimo } = req.body;

    if (!titulo || !asignatura_id) {
      return res.status(400).json({ error: 'titulo y asignatura_id son obligatorios.' });
    }
    if (!req.file) {
      return res.status(400).json({ error: 'Debe adjuntar un archivo (campo "archivo").' });
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
    return next(err);
  }
}

/** RF-12: el administrador edita un material (p. ej. corrige metadatos o cambia su estado). */
async function actualizar(req, res, next) {
  try {
    const { id } = req.params;
    const { titulo, descripcion, profesor, periodo_academico, estado } = req.body;

    const { rows } = await pool.query(
      `UPDATE materiales SET
         titulo = COALESCE($1, titulo),
         descripcion = COALESCE($2, descripcion),
         profesor = COALESCE($3, profesor),
         periodo_academico = COALESCE($4, periodo_academico),
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
    const { rowCount } = await pool.query('DELETE FROM materiales WHERE id = $1', [id]);
    if (!rowCount) return res.status(404).json({ error: 'Material no encontrado.' });
    return res.status(204).send();
  } catch (err) {
    return next(err);
  }
}

module.exports = { listar, obtener, crear, actualizar, eliminar };
