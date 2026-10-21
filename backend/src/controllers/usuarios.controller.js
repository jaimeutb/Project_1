const bcrypt = require('bcryptjs');
const { pool } = require('../config/db');

const ROLES = ['estudiante', 'administrador'];
const CAMPOS_PUBLICOS = 'id, nombre, correo, rol, activo, creado_en';

/** RF-13: el administrador consulta los usuarios registrados. */
async function listar(req, res, next) {
  try {
    const { rows } = await pool.query(
      `SELECT ${CAMPOS_PUBLICOS} FROM usuarios ORDER BY creado_en DESC`
    );
    return res.json(rows);
  } catch (err) {
    return next(err);
  }
}

/** RF-13: el administrador crea un usuario (estudiante o administrador). */
async function crear(req, res, next) {
  try {
    const { nombre, correo, contrasena, rol = 'estudiante' } = req.body;

    if (!nombre || !correo || !contrasena) {
      return res.status(400).json({ error: 'nombre, correo y contrasena son obligatorios.' });
    }
    if (contrasena.length < 8) {
      return res.status(400).json({ error: 'La contraseña debe tener al menos 8 caracteres.' });
    }
    if (!ROLES.includes(rol)) {
      return res.status(400).json({ error: 'rol inválido.' });
    }

    // RNF-04: la contraseña nunca se guarda en texto plano.
    const hash = await bcrypt.hash(contrasena, 10);
    const { rows } = await pool.query(
      `INSERT INTO usuarios (nombre, correo, contrasena_hash, rol)
       VALUES ($1, $2, $3, $4)
       RETURNING ${CAMPOS_PUBLICOS}`,
      [nombre, correo, hash, rol]
    );
    return res.status(201).json(rows[0]);
  } catch (err) {
    return next(err);
  }
}

/**
 * RF-13: el administrador edita un usuario (nombre, correo, rol) o lo
 * desactiva / reactiva (activo). Los campos no enviados se conservan.
 */
async function actualizar(req, res, next) {
  try {
    const id = Number(req.params.id);
    const { nombre, correo, rol, activo } = req.body;

    if ((nombre !== undefined && !String(nombre).trim()) ||
        (correo !== undefined && !String(correo).trim())) {
      return res.status(400).json({ error: 'nombre y correo no pueden quedar vacíos.' });
    }
    if (rol !== undefined && !ROLES.includes(rol)) {
      return res.status(400).json({ error: 'rol inválido.' });
    }
    if (activo !== undefined && typeof activo !== 'boolean') {
      return res.status(400).json({ error: 'activo debe ser true o false.' });
    }
    // Evita que el administrador se bloquee a sí mismo y la plataforma quede sin administrador.
    if (id === req.usuario.id && (activo === false || rol === 'estudiante')) {
      return res.status(400).json({ error: 'No puede desactivarse ni quitarse el rol de administrador a sí mismo.' });
    }

    const { rows } = await pool.query(
      `UPDATE usuarios SET
         nombre = COALESCE($1, nombre),
         correo = COALESCE($2, correo),
         rol    = COALESCE($3, rol),
         activo = COALESCE($4, activo)
       WHERE id = $5
       RETURNING ${CAMPOS_PUBLICOS}`,
      [nombre, correo, rol, activo, id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Usuario no encontrado.' });
    return res.json(rows[0]);
  } catch (err) {
    return next(err);
  }
}

/** RF-13: el administrador cambia el rol de un usuario (p. ej. promueve a administrador). */
async function actualizarRol(req, res, next) {
  const { rol } = req.body;
  if (!ROLES.includes(rol)) {
    return res.status(400).json({ error: 'rol inválido.' });
  }
  req.body = { rol };
  return actualizar(req, res, next);
}

module.exports = { listar, crear, actualizar, actualizarRol };
