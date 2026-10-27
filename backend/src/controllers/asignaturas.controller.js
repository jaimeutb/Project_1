const { pool } = require('../config/db');

/**
 * RF-03: listado de asignaturas, usado por el frontend para armar el buscador.
 * Solo se listan las asignaturas activas; el administrador puede pedir también
 * las desactivadas con ?incluir_inactivas=true (RF-13).
 */
async function listar(req, res, next) {
  try {
    const incluirInactivas =
      req.query.incluir_inactivas === 'true' && req.usuario.rol === 'administrador';
    // total_materiales: material visible para los estudiantes (para el panel de inicio).
    const { rows } = await pool.query(
      `SELECT a.*,
              (SELECT COUNT(*) FROM materiales m
                WHERE m.asignatura_id = a.id
                  AND m.estado IN ('publicado', 'reportado', 'en_revision'))::int AS total_materiales
       FROM asignaturas a
       ${incluirInactivas ? '' : 'WHERE a.activo'}
       ORDER BY a.nombre ASC`
    );
    return res.json(rows);
  } catch (err) {
    return next(err);
  }
}

/** RF-13: el administrador crea asignaturas. */
async function crear(req, res, next) {
  try {
    const { nombre, codigo, semestre } = req.body;
    if (!nombre || !codigo || !semestre) {
      return res.status(400).json({ error: 'nombre, codigo y semestre son obligatorios.' });
    }
    const { rows } = await pool.query(
      `INSERT INTO asignaturas (nombre, codigo, semestre) VALUES ($1, $2, $3) RETURNING *`,
      [nombre, codigo, semestre]
    );
    return res.status(201).json(rows[0]);
  } catch (err) {
    return next(err);
  }
}

/**
 * RF-13: el administrador edita una asignatura o la desactiva / reactiva
 * (activo). Una asignatura desactivada deja de aparecer en el buscador y no
 * admite material nuevo, pero su material existente se conserva.
 */
async function actualizar(req, res, next) {
  try {
    const { id } = req.params;
    const { nombre, codigo, semestre, activo } = req.body;
    if (activo !== undefined && typeof activo !== 'boolean') {
      return res.status(400).json({ error: 'activo debe ser true o false.' });
    }
    const { rows } = await pool.query(
      `UPDATE asignaturas SET nombre = COALESCE($1, nombre), codigo = COALESCE($2, codigo),
              semestre = COALESCE($3, semestre), activo = COALESCE($4, activo)
       WHERE id = $5 RETURNING *`,
      [nombre || null, codigo || null, semestre || null, activo, id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Asignatura no encontrada.' });
    return res.json(rows[0]);
  } catch (err) {
    return next(err);
  }
}

module.exports = { listar, crear, actualizar };
