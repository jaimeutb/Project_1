// Prueba de extremo a extremo contra un PostgreSQL real: recorre los criterios de
// aceptación de los RF/RNF del documento (sección 6).
//
// Usa la base configurada en backend/.env, pero trabaja dentro de un esquema
// temporal (test_<fecha>) que se elimina al terminar, así que no toca los datos
// de desarrollo. El usuario de la base necesita permiso para crear esquemas
// (el dueño de la base lo tiene).
//
// Uso: npm run test:e2e
require('dotenv').config();
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { Client } = require('pg');

const ESQUEMA = `test_${Date.now()}`;
// Todas las conexiones del backend (y del script crear-admin) usan el esquema temporal.
process.env.PGOPTIONS = `-c search_path=${ESQUEMA}`;
process.env.UPLOADS_DIR = 'uploads-test';

const app = require('../src/app');
const { pool } = require('../src/config/db');
const { uploadsDir } = require('../src/middleware/upload');

const datosConexion = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'apoyo_academico',
  user: process.env.DB_USER || 'apoyo_academico',
  password: process.env.DB_PASSWORD || '',
};

let server;
let base;
const t = {}; // tokens e ids compartidos entre pasos

async function ejecutarEsquema() {
  const sql = fs.readFileSync(path.join(__dirname, '..', 'src', 'db', 'schema.sql'), 'utf8');
  await pool.query(sql);
}

before(async () => {
  const admin = new Client(datosConexion);
  await admin.connect();
  await admin.query(`CREATE SCHEMA ${ESQUEMA}`);
  await admin.end();

  await ejecutarEsquema();
  await ejecutarEsquema(); // el esquema debe poder aplicarse dos veces (idempotente)

  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (server) await new Promise((resolve) => server.close(resolve));
  await pool.end();
  const admin = new Client(datosConexion);
  await admin.connect();
  await admin.query(`DROP SCHEMA IF EXISTS ${ESQUEMA} CASCADE`);
  await admin.end();
  fs.rmSync(uploadsDir, { recursive: true, force: true });
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
  const texto = await res.text();
  return { status: res.status, body: texto ? JSON.parse(texto) : null };
}

async function subir(token, campos, { tipo = 'application/pdf', nombre = 'parcial.pdf', contenido = '%PDF-1.4 prueba' } = {}) {
  const form = new FormData();
  for (const [k, v] of Object.entries(campos)) form.append(k, String(v));
  form.append('archivo', new Blob([contenido], { type: tipo }), nombre);
  const res = await fetch(`${base}/api/materiales`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}` },
    body: form,
  });
  return { status: res.status, body: await res.json() };
}

function sinCamposSensibles(obj) {
  assert.ok(!JSON.stringify(obj).includes('contrasena_hash'), 'no debe exponer contrasena_hash');
}

test('RF-01: registro de estudiante', async () => {
  const res = await pedir('POST', '/api/auth/registro', {
    body: { nombre: 'Ana Estudiante', correo: 'ana@uni.edu.co', contrasena: 'clave-segura-1' },
  });
  assert.equal(res.status, 201);
  assert.equal(res.body.usuario.rol, 'estudiante');
  assert.ok(res.body.token);
  sinCamposSensibles(res.body);
  t.ana = res.body.token;
  t.anaId = res.body.usuario.id;

  const duplicado = await pedir('POST', '/api/auth/registro', {
    body: { nombre: 'Otra', correo: 'ana@uni.edu.co', contrasena: 'clave-segura-1' },
  });
  assert.equal(duplicado.status, 409);

  const res2 = await pedir('POST', '/api/auth/registro', {
    body: { nombre: 'Beto Estudiante', correo: 'beto@uni.edu.co', contrasena: 'clave-segura-2' },
  });
  t.beto = res2.body.token;
});

test('RNF-04: la contraseña se guarda cifrada (bcrypt)', async () => {
  const { rows } = await pool.query(`SELECT contrasena_hash FROM usuarios WHERE correo = 'ana@uni.edu.co'`);
  assert.match(rows[0].contrasena_hash, /^\$2[aby]\$/);
  assert.ok(!rows[0].contrasena_hash.includes('clave-segura-1'));
});

test('npm run crear-admin crea el primer administrador', () => {
  const salida = execFileSync(
    process.execPath,
    [path.join(__dirname, '..', 'src', 'db', 'crear-admin.js'), 'Admin Plataforma', 'admin@uni.edu.co', 'admin-clave-1'],
    { env: process.env, encoding: 'utf8' }
  );
  assert.match(salida, /creado/);
});

test('RF-02: inicio de sesión y perfil', async () => {
  const malo = await pedir('POST', '/api/auth/login', { body: { correo: 'admin@uni.edu.co', contrasena: 'incorrecta' } });
  assert.equal(malo.status, 401);

  const res = await pedir('POST', '/api/auth/login', { body: { correo: 'admin@uni.edu.co', contrasena: 'admin-clave-1' } });
  assert.equal(res.status, 200);
  assert.equal(res.body.usuario.rol, 'administrador');
  sinCamposSensibles(res.body);
  t.admin = res.body.token;
  t.adminId = res.body.usuario.id;

  const perfil = await pedir('GET', '/api/auth/perfil', { token: t.ana });
  assert.equal(perfil.status, 200);
  assert.equal(perfil.body.correo, 'ana@uni.edu.co');
  sinCamposSensibles(perfil.body);
});

test('RF-13: gestión de asignaturas (crear, editar, desactivar)', async () => {
  const prohibido = await pedir('POST', '/api/asignaturas', {
    token: t.ana, body: { nombre: 'X', codigo: 'X', semestre: '1' },
  });
  assert.equal(prohibido.status, 403);

  const calculo = await pedir('POST', '/api/asignaturas', {
    token: t.admin, body: { nombre: 'Cálculo I', codigo: 'MAT101', semestre: '1' },
  });
  assert.equal(calculo.status, 201);
  t.calculo = calculo.body.id;

  const fisica = await pedir('POST', '/api/asignaturas', {
    token: t.admin, body: { nombre: 'Física', codigo: 'FIS201', semestre: '2' },
  });
  t.fisica = fisica.body.id;

  const quimica = await pedir('POST', '/api/asignaturas', {
    token: t.admin, body: { nombre: 'Química', codigo: 'QUI100', semestre: '1' },
  });
  t.quimica = quimica.body.id;

  const editada = await pedir('PUT', `/api/asignaturas/${t.fisica}`, {
    token: t.admin, body: { nombre: 'Física Mecánica' },
  });
  assert.equal(editada.body.nombre, 'Física Mecánica');
  assert.equal(editada.body.codigo, 'FIS201');

  const desactivada = await pedir('PUT', `/api/asignaturas/${t.quimica}`, {
    token: t.admin, body: { activo: false },
  });
  assert.equal(desactivada.body.activo, false);

  const paraEstudiante = await pedir('GET', '/api/asignaturas', { token: t.ana });
  assert.deepEqual(paraEstudiante.body.map((a) => a.codigo).sort(), ['FIS201', 'MAT101']);

  const paraAdmin = await pedir('GET', '/api/asignaturas?incluir_inactivas=true', { token: t.admin });
  assert.equal(paraAdmin.body.length, 3);
});

test('RF-13: gestión de usuarios (crear, editar, desactivar)', async () => {
  const creado = await pedir('POST', '/api/usuarios', {
    token: t.admin, body: { nombre: 'Carla', correo: 'carla@uni.edu.co', contrasena: 'clave-carla-1' },
  });
  assert.equal(creado.status, 201);
  assert.equal(creado.body.rol, 'estudiante');
  sinCamposSensibles(creado.body);

  const editado = await pedir('PUT', `/api/usuarios/${creado.body.id}`, {
    token: t.admin, body: { nombre: 'Carla Gómez' },
  });
  assert.equal(editado.body.nombre, 'Carla Gómez');

  const desactivado = await pedir('PUT', `/api/usuarios/${creado.body.id}`, {
    token: t.admin, body: { activo: false },
  });
  assert.equal(desactivado.body.activo, false);

  const login = await pedir('POST', '/api/auth/login', { body: { correo: 'carla@uni.edu.co', contrasena: 'clave-carla-1' } });
  assert.equal(login.status, 403);

  const autoBloqueo = await pedir('PUT', `/api/usuarios/${t.adminId}`, {
    token: t.admin, body: { activo: false },
  });
  assert.equal(autoBloqueo.status, 400);

  const lista = await pedir('GET', '/api/usuarios', { token: t.admin });
  assert.equal(lista.status, 200);
  assert.equal(lista.body.length, 4);
  sinCamposSensibles(lista.body);
});

test('RF-06/RF-07/RF-11: carga de material (normal y anónima, con metadatos)', async () => {
  const anonimo = await subir(t.ana, {
    titulo: 'Parcial 1 de Cálculo', descripcion: 'Límites y derivadas', asignatura_id: t.calculo,
    profesor: 'Prof. Ruiz', periodo_academico: '2026-1', es_anonimo: true,
  });
  assert.equal(anonimo.status, 201);
  t.parcialCalculo = anonimo.body.id;
  t.archivoCalculo = anonimo.body.archivo_url;
  assert.ok(fs.existsSync(path.join(uploadsDir, path.basename(t.archivoCalculo))));

  const normal = await subir(t.beto, {
    titulo: 'Taller de cinemática', asignatura_id: t.fisica, es_anonimo: false,
  });
  assert.equal(normal.status, 201);
  t.tallerFisica = normal.body.id;

  // El frontend Flutter envía los archivos como "application/octet-stream":
  // se aceptan si la extensión es válida.
  const desdeFlutter = await subir(t.beto, {
    titulo: 'Ejercicios de SQL', asignatura_id: t.fisica,
  }, { tipo: 'application/octet-stream', nombre: 'ejercicios.PDF' });
  assert.equal(desdeFlutter.status, 201);
  await pedir('DELETE', `/api/materiales/${desdeFlutter.body.id}`, { token: t.admin });

  const tipoInvalido = await subir(t.ana, { titulo: 'x', asignatura_id: t.calculo }, { tipo: 'text/plain', nombre: 'x.txt' });
  assert.equal(tipoInvalido.status, 400);
  const extensionInvalida = await subir(t.ana, { titulo: 'x', asignatura_id: t.calculo }, { tipo: 'application/octet-stream', nombre: 'programa.exe' });
  assert.equal(extensionInvalida.status, 400);
  const tipoQueNoCoincide = await subir(t.ana, { titulo: 'x', asignatura_id: t.calculo }, { tipo: 'text/html', nombre: 'falso.pdf' });
  assert.equal(tipoQueNoCoincide.status, 400);

  const asignaturaInactiva = await subir(t.ana, { titulo: 'x', asignatura_id: t.quimica });
  assert.equal(asignaturaInactiva.status, 400);
  // Ningún archivo rechazado o eliminado queda huérfano en disco (solo los 2
  // aceptados). Se espera un instante: el borrado de archivos es asíncrono.
  await new Promise((r) => setTimeout(r, 100));
  assert.equal(fs.readdirSync(uploadsDir).length, 2);
});

test('RF-07: el material anónimo no muestra a su autor', async () => {
  const anonimo = await pedir('GET', `/api/materiales/${t.parcialCalculo}`, { token: t.beto });
  assert.equal(anonimo.body.autor_nombre, null);
  const normal = await pedir('GET', `/api/materiales/${t.tallerFisica}`, { token: t.ana });
  assert.equal(normal.body.autor_nombre, 'Beto Estudiante');
});

test('RF-03/RF-04: búsqueda por asignatura y filtro por semestre o tema', async () => {
  const porAsignatura = await pedir('GET', `/api/materiales?asignatura_id=${t.calculo}`, { token: t.ana });
  assert.deepEqual(porAsignatura.body.map((m) => m.id), [t.parcialCalculo]);

  const porSemestre = await pedir('GET', '/api/materiales?semestre=2', { token: t.ana });
  assert.deepEqual(porSemestre.body.map((m) => m.id), [t.tallerFisica]);

  const porTema = await pedir('GET', '/api/materiales?q=derivadas', { token: t.ana });
  assert.deepEqual(porTema.body.map((m) => m.id), [t.parcialCalculo]);

  const todos = await pedir('GET', '/api/materiales', { token: t.ana });
  assert.equal(todos.body.length, 2);
});

test('RF-05/RF-11: ficha del material y descarga del archivo', async () => {
  const ficha = await pedir('GET', `/api/materiales/${t.parcialCalculo}`, { token: t.beto });
  assert.equal(ficha.status, 200);
  assert.equal(ficha.body.profesor, 'Prof. Ruiz');
  assert.equal(ficha.body.periodo_academico, '2026-1');
  assert.ok(ficha.body.fecha_publicacion);

  const archivo = await fetch(base + t.archivoCalculo);
  assert.equal(archivo.status, 200);
  assert.equal(await archivo.text(), '%PDF-1.4 prueba');

  const idInvalido = await pedir('GET', '/api/materiales/abc', { token: t.ana });
  assert.equal(idInvalido.status, 400);
});

test('RF-08/RNF-05: valoración y comentarios, con promedio visible', async () => {
  const invalida = await pedir('POST', `/api/materiales/${t.parcialCalculo}/valoraciones`, {
    token: t.beto, body: { puntuacion: 6 },
  });
  assert.equal(invalida.status, 400);

  await pedir('POST', `/api/materiales/${t.parcialCalculo}/valoraciones`, {
    token: t.beto, body: { puntuacion: 3, comentario: 'Útil' },
  });
  // Un estudiante valora una sola vez: la segunda valoración reemplaza a la primera.
  await pedir('POST', `/api/materiales/${t.parcialCalculo}/valoraciones`, {
    token: t.beto, body: { puntuacion: 4, comentario: 'Muy útil para el parcial' },
  });
  await pedir('POST', `/api/materiales/${t.parcialCalculo}/valoraciones`, {
    token: t.ana, body: { puntuacion: 5 },
  });

  const ficha = await pedir('GET', `/api/materiales/${t.parcialCalculo}`, { token: t.ana });
  assert.equal(Number(ficha.body.calificacion_promedio), 4.5);
  assert.equal(Number(ficha.body.total_valoraciones), 2);

  const comentarios = await pedir('GET', `/api/materiales/${t.parcialCalculo}/valoraciones`, { token: t.ana });
  assert.equal(comentarios.body.length, 2);
  assert.ok(comentarios.body.some((v) => v.comentario === 'Muy útil para el parcial'));
});

test('RF-09/RNF-05: reporte de contenido, visible como pendiente', async () => {
  const sinMotivo = await pedir('POST', `/api/materiales/${t.tallerFisica}/reportes`, { token: t.ana, body: {} });
  assert.equal(sinMotivo.status, 400);

  const reporte = await pedir('POST', `/api/materiales/${t.tallerFisica}/reportes`, {
    token: t.ana, body: { motivo: 'Profesor distinto' },
  });
  assert.equal(reporte.status, 201);
  assert.equal(reporte.body.estado, 'pendiente');
  assert.ok(reporte.body.creado_en);
  t.reporte = reporte.body.id;

  const ficha = await pedir('GET', `/api/materiales/${t.tallerFisica}`, { token: t.beto });
  assert.equal(ficha.body.estado, 'reportado');
  assert.equal(Number(ficha.body.reportes_pendientes), 1);
});

test('RF-10: el administrador revisa los reportes y cambia su estado', async () => {
  const prohibido = await pedir('GET', '/api/reportes', { token: t.ana });
  assert.equal(prohibido.status, 403);

  const pendientes = await pedir('GET', '/api/reportes?estado=pendiente', { token: t.admin });
  assert.deepEqual(pendientes.body.map((r) => r.id), [t.reporte]);
  assert.equal(pendientes.body[0].reportado_por, 'Ana Estudiante');

  // Un segundo reporte sobre el mismo material.
  const otro = await pedir('POST', `/api/materiales/${t.tallerFisica}/reportes`, {
    token: t.beto, body: { motivo: 'Desactualizado' },
  });

  const resuelto = await pedir('PATCH', `/api/reportes/${t.reporte}`, {
    token: t.admin, body: { estado: 'resuelto' },
  });
  assert.equal(resuelto.body.estado, 'resuelto');
  assert.ok(resuelto.body.resuelto_en, 'la acción queda registrada con fecha');
  // Aún queda un reporte pendiente: el material sigue «En revisión».
  assert.equal(resuelto.body.material_estado, 'reportado');

  const descartado = await pedir('PATCH', `/api/reportes/${otro.body.id}`, {
    token: t.admin, body: { estado: 'descartado' },
  });
  // Se cerró el último reporte pendiente: el material vuelve a publicarse.
  assert.equal(descartado.body.material_estado, 'publicado');
  const ficha = await pedir('GET', `/api/materiales/${t.tallerFisica}`, { token: t.ana });
  assert.equal(ficha.body.estado, 'publicado');
  assert.equal(Number(ficha.body.reportes_pendientes), 0);

  // Un estado fijado a mano por el administrador no se cambia al cerrar reportes.
  await pedir('PUT', `/api/materiales/${t.parcialCalculo}`, { token: t.admin, body: { estado: 'en_revision' } });
  const reporte3 = await pedir('POST', `/api/materiales/${t.parcialCalculo}/reportes`, {
    token: t.beto, body: { motivo: 'Falta un ejercicio' },
  });
  const cerrado = await pedir('PATCH', `/api/reportes/${reporte3.body.id}`, {
    token: t.admin, body: { estado: 'resuelto' },
  });
  assert.equal(cerrado.body.material_estado, 'en_revision');
  await pedir('PUT', `/api/materiales/${t.parcialCalculo}`, { token: t.admin, body: { estado: 'publicado' } });

  const invalido = await pedir('PATCH', `/api/reportes/${t.reporte}`, {
    token: t.admin, body: { estado: 'otro' },
  });
  assert.equal(invalido.status, 400);
  const inexistente = await pedir('PATCH', '/api/reportes/999999', {
    token: t.admin, body: { estado: 'resuelto' },
  });
  assert.equal(inexistente.status, 404);
});

test('RF-12: el administrador edita, retira y elimina material', async () => {
  const editado = await pedir('PUT', `/api/materiales/${t.tallerFisica}`, {
    token: t.admin, body: { titulo: 'Taller 1 de cinemática', profesor: 'Prof. Díaz', estado: 'publicado' },
  });
  assert.equal(editado.status, 200);
  const ficha = await pedir('GET', `/api/materiales/${t.tallerFisica}`, { token: t.ana });
  assert.equal(ficha.body.titulo, 'Taller 1 de cinemática');
  assert.equal(ficha.body.profesor, 'Prof. Díaz');

  // Un campo opcional enviado vacío se borra; los no enviados se conservan.
  const sinProfesor = await pedir('PUT', `/api/materiales/${t.tallerFisica}`, {
    token: t.admin, body: { profesor: '' },
  });
  assert.equal(sinProfesor.body.profesor, null);
  assert.equal(sinProfesor.body.titulo, 'Taller 1 de cinemática');
  const tituloVacio = await pedir('PUT', `/api/materiales/${t.tallerFisica}`, {
    token: t.admin, body: { titulo: ' ' },
  });
  assert.equal(tituloVacio.status, 400);

  await pedir('PUT', `/api/materiales/${t.tallerFisica}`, { token: t.admin, body: { estado: 'retirado' } });
  const paraEstudiante = await pedir('GET', '/api/materiales', { token: t.ana });
  assert.ok(!paraEstudiante.body.some((m) => m.id === t.tallerFisica), 'el estudiante no ve material retirado');
  const fichaRetirada = await pedir('GET', `/api/materiales/${t.tallerFisica}`, { token: t.ana });
  assert.equal(fichaRetirada.status, 404);
  const paraAdmin = await pedir('GET', '/api/materiales', { token: t.admin });
  assert.ok(paraAdmin.body.some((m) => m.id === t.tallerFisica), 'el administrador sí lo ve, para republicarlo');

  const eliminado = await pedir('DELETE', `/api/materiales/${t.parcialCalculo}`, { token: t.admin });
  assert.equal(eliminado.status, 204);
  const despues = await pedir('GET', `/api/materiales/${t.parcialCalculo}`, { token: t.admin });
  assert.equal(despues.status, 404);
  // El archivo físico también se borra (se espera un instante: el borrado es asíncrono).
  await new Promise((r) => setTimeout(r, 100));
  assert.ok(!fs.existsSync(path.join(uploadsDir, path.basename(t.archivoCalculo))));
});
