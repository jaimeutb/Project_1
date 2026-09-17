const { pool } = require('../config/db');

/** RF-08: un estudiante califica (1-5) y comenta un material. Una valoración por usuario/material. */
async function crear(req, res, next) {
  try {
    const { material_id } = req.params;
    const { puntuacion, comentario } = req.body;

    if (!puntuacion || puntuacion < 1 || puntuacion > 5) {
      return res.status(400).json({ error: 'puntuacion debe estar entre 1 y 5.' });
    }

    const { rows } = await pool.query(
      `INSERT INTO valoraciones (puntuacion, comentario, material_id, usuario_id)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (material_id, usuario_id)
       DO UPDATE SET puntuacion = EXCLUDED.puntuacion, comentario = EXCLUDED.comentario
       RETURNING *`,
      [puntuacion, comentario || null, material_id, req.usuario.id]
    );
    return res.status(201).json(rows[0]);
  } catch (err) {
    return next(err);
  }
}

/** Lista las valoraciones (con comentario) de un material específico. */
async function listarPorMaterial(req, res, next) {
  try {
    const { material_id } = req.params;
    const { rows } = await pool.query(
      `SELECT v.id, v.puntuacion, v.comentario, v.creado_en, u.nombre AS autor
       FROM valoraciones v JOIN usuarios u ON u.id = v.usuario_id
       WHERE v.material_id = $1
       ORDER BY v.creado_en DESC`,
      [material_id]
    );
    return res.json(rows);
  } catch (err) {
    return next(err);
  }
}

module.exports = { crear, listarPorMaterial };
