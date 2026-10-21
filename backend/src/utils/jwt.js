const jwt = require('jsonwebtoken');
require('dotenv').config();

// RNF-04: en producción es obligatorio definir JWT_SECRET; el valor por
// defecto solo sirve para desarrollo local.
if (process.env.NODE_ENV === 'production' && !process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET no está definido en el entorno de producción.');
}
const SECRET = process.env.JWT_SECRET || 'dev-secret-cambiar-en-produccion';
const EXPIRES_IN = process.env.JWT_EXPIRES_IN || '8h';

/** Firma un token para un usuario autenticado (RF-02 / RNF-04). */
function firmarToken(usuario) {
  return jwt.sign(
    { id: usuario.id, rol: usuario.rol, nombre: usuario.nombre },
    SECRET,
    { expiresIn: EXPIRES_IN }
  );
}

function verificarToken(token) {
  return jwt.verify(token, SECRET);
}

module.exports = { firmarToken, verificarToken };
