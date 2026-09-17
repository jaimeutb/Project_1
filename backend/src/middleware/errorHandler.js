// Middleware central de manejo de errores para toda la API.
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  console.error(err);

  if (err.code === '23505') {
    // violación de restricción UNIQUE de PostgreSQL
    return res.status(409).json({ error: 'El registro ya existe (valor duplicado).' });
  }
  if (err.code === '23503') {
    return res.status(400).json({ error: 'Referencia inválida a otro recurso.' });
  }
  if (err.code === '23514') {
    return res.status(400).json({ error: 'El valor enviado no cumple una restricción del sistema.' });
  }

  const status = err.status || 500;
  return res.status(status).json({ error: err.message || 'Error interno del servidor.' });
}

module.exports = { errorHandler };
