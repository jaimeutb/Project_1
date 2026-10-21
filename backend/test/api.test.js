// Pruebas rápidas de la API que NO necesitan base de datos: control de acceso
// (RNF-04) y validaciones que responden antes de consultar PostgreSQL.
// Uso: npm test
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');

const app = require('../src/app');
const { pool } = require('../src/config/db');
const { firmarToken } = require('../src/utils/jwt');

let server;
let base;
const tokenEstudiante = firmarToken({ id: 1, rol: 'estudiante', nombre: 'Prueba' });

before(async () => {
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
  await pool.end();
});

async function pedir(metodo, ruta, { token, body } = {}) {
  const res = await fetch(base + ruta, {
    method: metodo,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  return { status: res.status, body: await res.json().catch(() => null) };
}

test('GET /api/salud responde ok', async () => {
  const res = await pedir('GET', '/api/salud');
  assert.equal(res.status, 200);
  assert.equal(res.body.estado, 'ok');
});

test('una ruta inexistente responde 404', async () => {
  const res = await pedir('GET', '/api/no-existe');
  assert.equal(res.status, 404);
});

test('RNF-04: sin token no se accede al material', async () => {
  for (const [metodo, ruta] of [
    ['GET', '/api/materiales'],
    ['GET', '/api/materiales/1'],
    ['POST', '/api/materiales'],
    ['GET', '/api/asignaturas'],
    ['GET', '/api/auth/perfil'],
  ]) {
    const res = await pedir(metodo, ruta);
    assert.equal(res.status, 401, `${metodo} ${ruta}`);
  }
});

test('RNF-04: un token inválido se rechaza', async () => {
  const res = await pedir('GET', '/api/materiales', { token: 'no-es-un-jwt' });
  assert.equal(res.status, 401);
});

test('RNF-04: un estudiante no accede a funciones de administrador', async () => {
  for (const [metodo, ruta, body] of [
    ['GET', '/api/usuarios'],
    ['POST', '/api/usuarios', { nombre: 'x', correo: 'x@x.co', contrasena: '12345678' }],
    ['PUT', '/api/usuarios/1', { activo: false }],
    ['PATCH', '/api/usuarios/1/rol', { rol: 'administrador' }],
    ['POST', '/api/asignaturas', { nombre: 'x', codigo: 'x', semestre: '1' }],
    ['PUT', '/api/asignaturas/1', { activo: false }],
    ['PUT', '/api/materiales/1', { estado: 'retirado' }],
    ['DELETE', '/api/materiales/1'],
    ['GET', '/api/reportes'],
    ['PATCH', '/api/reportes/1', { estado: 'resuelto' }],
  ]) {
    const res = await pedir(metodo, ruta, { token: tokenEstudiante, body });
    assert.equal(res.status, 403, `${metodo} ${ruta}`);
  }
});

test('RF-01: el registro exige nombre, correo y contraseña de 8+ caracteres', async () => {
  let res = await pedir('POST', '/api/auth/registro', { body: { correo: 'a@b.co' } });
  assert.equal(res.status, 400);
  res = await pedir('POST', '/api/auth/registro', {
    body: { nombre: 'Ana', correo: 'a@b.co', contrasena: 'corta' },
  });
  assert.equal(res.status, 400);
});

test('RF-02: el inicio de sesión exige correo y contraseña', async () => {
  const res = await pedir('POST', '/api/auth/login', { body: { correo: 'a@b.co' } });
  assert.equal(res.status, 400);
});
