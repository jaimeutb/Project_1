const { verificarToken } = require('../utils/jwt');

/**
 * RNF-04 (Seguridad de la información): exige un token válido y adjunta
 * el usuario autenticado a req.usuario.
 */
function requiereAutenticacion(req, res, next) {
  const header = req.headers.authorization || '';
  const [tipo, token] = header.split(' ');

  if (tipo !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'Token de autenticación requerido.' });
  }

  try {
    req.usuario = verificarToken(token);
    return next();
  } catch (err) {
    return res.status(401).json({ error: 'Token inválido o expirado.' });
  }
}

/**
 * RNF-04: restringe una ruta a uno o más roles (p. ej. 'administrador').
 * Ningún usuario sin el rol requerido puede acceder (criterio de aceptación RNF-04).
 */
function requiereRol(...rolesPermitidos) {
  return (req, res, next) => {
    if (!req.usuario || !rolesPermitidos.includes(req.usuario.rol)) {
      return res.status(403).json({ error: 'No tiene permisos para esta acción.' });
    }
    return next();
  };
}

module.exports = { requiereAutenticacion, requiereRol };
