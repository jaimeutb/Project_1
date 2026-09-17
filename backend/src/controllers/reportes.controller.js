const { pool } = require('../config/db');

/**
 * RF-09: un estudiante reporta un material (motivo: desactualizado, incorrecto,
 * profesor distinto, etc.). El material queda marcado como 'reportado' para que
 * los demás estudiantes vean que está en revisión (RNF-05).
 */
async function crear(req, res, next) {
  try {
    const { material_id } = req.params;
    const { motivo } = req.body;

    if (!motivo || !motivo.trim()) {
      return res.status(400).json({ error: 'motivo es obligatorio.' });
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const { rows } = await client.query(
        `INSERT INTO reportes (motivo, material_id, usuario_id)
         VALUES ($1, $2, $3) RETURNING *`,
        [motivo.trim(), material_id, req.usuario.id]
      );

      await client.query(
        `UPDATE materiales SET estado = 'reportado'
         WHERE id = $1 AND estado = 'publicado'`,
        [material_id]
      );

      await client.query('COMMIT');
      return res.status(201).json(rows[0]);
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    return next(err);
  }
}

/** RF-10: el administrador revisa los reportes recibidos (con filtro opcional por estado). */
async function listar(req, res, next) {
  try {
    const { estado } = req.query;
    const condiciones = [];
    const valores = [];
    if (estado) {
      valores.push(estado);
      condiciones.push(`r.estado = $${valores.length}`);
    }
    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : '';

    const { rows } = await pool.query(
      `SELECT r.id, r.motivo, r.estado, r.creado_en, r.resuelto_en,
              r.material_id, m.titulo AS material_titulo,
              u.nombre AS reportado_por
       FROM reportes r
       JOIN materiales m ON m.id = r.material_id
       JOIN usuarios u ON u.id = r.usuario_id
       ${where}
       ORDER BY r.creado_en DESC`,
      valores
    );
    return res.json(rows);
  } catch (err) {
    return next(err);
  }
}

/** RF-10: el administrador actualiza el estado de un reporte (pendiente/resuelto/descartado). */
async function actualizarEstado(req, res, next) {
  try {
    const { id } = req.params;
    const { estado } = req.body;

    if (!['pendiente', 'resuelto', 'descartado'].includes(estado)) {
      return res.status(400).json({ error: 'estado inválido.' });
    }

    const resueltoEn = estado === 'pendiente' ? null : new Date();
    const { rows } = await pool.query(
      `UPDATE reportes SET estado = $1, resuelto_en = $2 WHERE id = $3 RETURNING *`,
      [estado, resueltoEn, id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Reporte no encontrado.' });
    return res.json(rows[0]);
  } catch (err) {
    return next(err);
  }
}

module.exports = { crear, listar, actualizarEstado };
