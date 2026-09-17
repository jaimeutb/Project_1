const { pool } = require('../config/db');

/** RF-13: el administrador consulta los usuarios registrados. */
async function listar(req, res, next) {
  try {
    const { rows } = await pool.query(
      'SELECT id, nombre, correo, rol, creado_en FROM usuarios ORDER BY creado_en DESC'
    );
    return res.json(rows);
  } catch (err) {
    return next(err);
  }
}

/** RF-13: el administrador cambia el rol de un usuario (p. ej. promueve a administrador). */
async function actualizarRol(req, res, next) {
  try {
    const { id } = req.params;
    const { rol } = req.body;
    if (!['estudiante', 'administrador'].includes(rol)) {
      return res.status(400).json({ error: 'rol inválido.' });
    }
    const { rows } = await pool.query(
      'UPDATE usuarios SET rol = $1 WHERE id = $2 RETURNING id, nombre, correo, rol',
      [rol, id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Usuario no encontrado.' });
    return res.json(rows[0]);
  } catch (err) {
    return next(err);
  }
}

module.exports = { listar, actualizarRol };
