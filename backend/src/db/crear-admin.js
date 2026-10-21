// Crea el primer administrador de la plataforma (el registro público siempre
// crea estudiantes, RF-01). Si el correo ya existe, promueve esa cuenta a
// administrador y la reactiva, sin cambiar su contraseña.
//
// Uso: npm run crear-admin -- "Nombre Apellido" correo@ejemplo.com "contraseña"
const bcrypt = require('bcryptjs');
const { pool } = require('../config/db');

async function crearAdmin() {
  const [nombre, correo, contrasena] = process.argv.slice(2);
  if (!nombre || !correo) {
    console.error('Uso: npm run crear-admin -- "Nombre" correo@ejemplo.com "contraseña"');
    process.exitCode = 1;
    return;
  }

  try {
    const existente = await pool.query('SELECT id FROM usuarios WHERE correo = $1', [correo]);
    if (existente.rows[0]) {
      await pool.query(
        `UPDATE usuarios SET rol = 'administrador', activo = true WHERE id = $1`,
        [existente.rows[0].id]
      );
      console.log(`La cuenta ${correo} ahora es administrador.`);
      return;
    }

    if (!contrasena || contrasena.length < 8) {
      console.error('La contraseña es obligatoria para una cuenta nueva (mínimo 8 caracteres).');
      process.exitCode = 1;
      return;
    }
    const hash = await bcrypt.hash(contrasena, 10);
    await pool.query(
      `INSERT INTO usuarios (nombre, correo, contrasena_hash, rol)
       VALUES ($1, $2, $3, 'administrador')`,
      [nombre, correo, hash]
    );
    console.log(`Administrador ${correo} creado.`);
  } catch (err) {
    console.error('Error creando el administrador:', err.message);
    process.exitCode = 1;
  } finally {
    await pool.end();
  }
}

crearAdmin();
