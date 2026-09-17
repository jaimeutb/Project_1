const { Pool } = require('pg');
require('dotenv').config();

// Pool de conexiones a PostgreSQL (ver docs/diagramas/05-componentes.png:
// el Backend API se conecta a PostgreSQL para toda la persistencia).
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'apoyo_academico',
  user: process.env.DB_USER || 'apoyo_academico',
  password: process.env.DB_PASSWORD || '',
});

pool.on('error', (err) => {
  // eslint-disable-next-line no-console
  console.error('Error inesperado en el pool de PostgreSQL', err);
});

module.exports = { pool };
