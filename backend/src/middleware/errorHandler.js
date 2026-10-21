// Middleware central de manejo de errores para toda la API.
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
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
  if (err.code === '22P02') {
    // p. ej. GET /api/materiales/abc: el id no es un número válido
    return res.status(400).json({ error: 'Formato de dato inválido.' });
  }
  if (err.name === 'MulterError') {
    // p. ej. archivo de más de 25 MB (LIMIT_FILE_SIZE)
    const mensaje = err.code === 'LIMIT_FILE_SIZE'
      ? 'El archivo supera el tamaño máximo permitido (25 MB).'
      : 'No fue posible procesar el archivo enviado.';
    return res.status(400).json({ error: mensaje });
  }

  const status = err.status || 500;
  if (status >= 500) {
    // Solo los errores inesperados se registran con su traza completa.
    console.error(err);
    return res.status(status).json({ error: 'Error interno del servidor.' });
  }
  return res.status(status).json({ error: err.message });
}

module.exports = { errorHandler };
