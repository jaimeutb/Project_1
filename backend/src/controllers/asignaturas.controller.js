const { pool } = require('../config/db');

/** RF-03: listado de asignaturas, usado por el frontend para armar el buscador. */
async function listar(req, res, next) {
  try {
    const { rows } = await pool.query('SELECT * FROM asignaturas ORDER BY nombre ASC');
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

/** RF-13: el administrador edita o desactiva (aquí: actualiza) una asignatura. */
async function actualizar(req, res, next) {
  try {
    const { id } = req.params;
    const { nombre, codigo, semestre } = req.body;
    const { rows } = await pool.query(
      `UPDATE asignaturas SET nombre = COALESCE($1, nombre), codigo = COALESCE($2, codigo),
              semestre = COALESCE($3, semestre)
       WHERE id = $4 RETURNING *`,
      [nombre, codigo, semestre, id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Asignatura no encontrada.' });
    return res.json(rows[0]);
  } catch (err) {
    return next(err);
  }
}

module.exports = { listar, crear, actualizar };
