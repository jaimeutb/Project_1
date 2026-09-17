const bcrypt = require('bcryptjs');
const { pool } = require('../config/db');
const { firmarToken } = require('../utils/jwt');

/** RF-01 (Registro de usuario). El rol por defecto es 'estudiante'. */
async function registrar(req, res, next) {
  try {
    const { nombre, correo, contrasena } = req.body;

    if (!nombre || !correo || !contrasena) {
      return res.status(400).json({ error: 'nombre, correo y contrasena son obligatorios.' });
    }
    if (contrasena.length < 8) {
      return res.status(400).json({ error: 'La contraseña debe tener al menos 8 caracteres.' });
    }

    // RNF-04: la contraseña nunca se guarda en texto plano.
    const hash = await bcrypt.hash(contrasena, 10);

    const { rows } = await pool.query(
      `INSERT INTO usuarios (nombre, correo, contrasena_hash, rol)
       VALUES ($1, $2, $3, 'estudiante')
       RETURNING id, nombre, correo, rol, creado_en`,
      [nombre, correo, hash]
    );

    const usuario = rows[0];
    const token = firmarToken(usuario);
    return res.status(201).json({ usuario, token });
  } catch (err) {
    return next(err);
  }
}

/** RF-02 (Inicio de sesión). Devuelve un JWT si las credenciales son válidas. */
async function iniciarSesion(req, res, next) {
  try {
    const { correo, contrasena } = req.body;
    if (!correo || !contrasena) {
      return res.status(400).json({ error: 'correo y contrasena son obligatorios.' });
    }

    const { rows } = await pool.query('SELECT * FROM usuarios WHERE correo = $1', [correo]);
    const usuario = rows[0];

    if (!usuario) {
      return res.status(401).json({ error: 'Credenciales inválidas.' });
    }

    const coincide = await bcrypt.compare(contrasena, usuario.contrasena_hash);
    if (!coincide) {
      return res.status(401).json({ error: 'Credenciales inválidas.' });
    }

    const token = firmarToken(usuario);
    return res.json({
      usuario: {
        id: usuario.id,
        nombre: usuario.nombre,
        correo: usuario.correo,
        rol: usuario.rol,
      },
      token,
    });
  } catch (err) {
    return next(err);
  }
}

/** Devuelve los datos del usuario autenticado (útil para el frontend al recargar). */
async function perfil(req, res, next) {
  try {
    const { rows } = await pool.query(
      'SELECT id, nombre, correo, rol, creado_en FROM usuarios WHERE id = $1',
      [req.usuario.id]
    );
    if (!rows[0]) return res.status(404).json({ error: 'Usuario no encontrado.' });
    return res.json(rows[0]);
  } catch (err) {
    return next(err);
  }
}

module.exports = { registrar, iniciarSesion, perfil };
