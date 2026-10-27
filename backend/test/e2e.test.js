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
// Las pruebas nunca usan una IA real, aunque backend/.env tenga una clave: sin
// proveedor falso, la plataforma se comporta como si no hubiera IA configurada.
process.env.GEMINI_API_KEY = '';
process.env.ANTHROPIC_API_KEY = '';

const app = require('../src/app');
const { pool } = require('../src/config/db');
const { uploadsDir } = require('../src/middleware/upload');
const tutor = require('../src/services/tutorIa');
const iaCtrl = require('../src/controllers/ia.controller');

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
  // contenido puede ser texto o un Buffer (un PDF real, para probar la vista previa).
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

test('H-01/H-02: el buscador encuentra la asignatura, por palabras y sin tildes', async () => {
  const buscar = async (q) => {
    const res = await pedir('GET', `/api/materiales?q=${encodeURIComponent(q)}`, { token: t.ana });
    assert.equal(res.status, 200, q);
    return res.body.map((m) => m.id);
  };

  // H-01: nombre y código de la asignatura, y palabras sueltas en distintos campos.
  assert.deepEqual(await buscar('física mecánica'), [t.tallerFisica]);
  assert.deepEqual(await buscar('mat101'), [t.parcialCalculo]);
  assert.deepEqual(await buscar('parcial cálculo'), [t.parcialCalculo]);
  assert.deepEqual(await buscar('derivadas del cálculo'), [t.parcialCalculo]);
  assert.deepEqual(await buscar('parcial física'), [], 'todas las palabras deben aparecer');

  // H-02: sin distinguir tildes ni mayúsculas.
  assert.deepEqual(await buscar('cinematica'), [t.tallerFisica]);
  assert.deepEqual(await buscar('CINEMÁTICA'), [t.tallerFisica]);
  assert.deepEqual(await buscar('calculo'), [t.parcialCalculo]);

  // Los comodines de LIKE no devuelven todo el material.
  assert.deepEqual(await buscar('%'), []);
  assert.deepEqual(await buscar('_'), []);
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

// Proveedor de IA falso: registra cada petición y devuelve la respuesta que la
// prueba prepare, sin llamar a Internet ni gastar la cuota de la API.
const iaFalsa = {
  nombre: 'falsa',
  modelo: 'modelo-de-prueba',
  peticiones: [],
  respuesta: null,
  async generar(params) {
    iaFalsa.peticiones.push(params);
    return iaFalsa.respuesta(params);
  },
};
const pdfDePrueba = fs.readFileSync(path.join(__dirname, '..', 'src', 'db', 'material-de-prueba', 'parcial-limites.pdf'));

test('RF-14: el Tutor IA explica el material leyendo su PDF, y la explicación se reutiliza', async () => {
  tutor.usarProveedor(iaFalsa);
  const explicacion = {
    resumen: 'Parcial de límites y derivadas.',
    temas: [{ nombre: 'Límites', explicacion: 'Un límite...', ejemplo: 'lim x→2 de x^2 = 4' }],
    ejercicios: [{ enunciado: 'Calcule lim x→0 sen(x)/x', pista: 'Límite notable', solucion: 'Es 1.' }],
    consejos: ['Repase los límites notables.'],
  };
  iaFalsa.respuesta = () => JSON.stringify(explicacion);

  const primera = await pedir('POST', `/api/materiales/${t.parcialCalculo}/ia/explicacion`, { token: t.beto });
  assert.equal(primera.status, 201);
  assert.deepEqual(primera.body.contenido, explicacion);
  assert.equal(primera.body.fuente, 'archivo');
  assert.equal(primera.body.guardado, false);

  // La petición lleva el PDF, los datos del material y el esquema de salida.
  const peticion = iaFalsa.peticiones.at(-1);
  const partes = peticion.mensajes[0].partes;
  assert.equal(partes[0].archivo.mimeType, 'application/pdf');
  assert.equal(Buffer.from(partes[0].archivo.base64, 'base64').toString(), '%PDF-1.4 prueba');
  assert.ok(partes[1].texto.includes('Parcial 1 de Cálculo'));
  assert.ok(partes[1].texto.includes('Prof. Ruiz'));
  assert.ok(peticion.esquema.properties.temas);
  // R-08: el nombre de quien subió un material anónimo tampoco se envía a la IA.
  assert.ok(!JSON.stringify(peticion).includes('Ana Estudiante'));

  // R-10: la segunda consulta sale de la base de datos, sin llamar a la IA.
  const antes = iaFalsa.peticiones.length;
  const segunda = await pedir('POST', `/api/materiales/${t.parcialCalculo}/ia/explicacion`, { token: t.ana });
  assert.equal(segunda.status, 200);
  assert.equal(segunda.body.guardado, true);
  assert.deepEqual(segunda.body.contenido, explicacion);
  assert.equal(iaFalsa.peticiones.length, antes);

  // Con { nueva: true } se genera otra vez y reemplaza la guardada.
  iaFalsa.respuesta = () => JSON.stringify({ ...explicacion, resumen: 'Otra versión.' });
  const nueva = await pedir('POST', `/api/materiales/${t.parcialCalculo}/ia/explicacion`, {
    token: t.ana, body: { nueva: true },
  });
  assert.equal(nueva.status, 201);
  assert.equal(nueva.body.contenido.resumen, 'Otra versión.');
  assert.equal(iaFalsa.peticiones.length, antes + 1);
});

test('RF-15: el Tutor IA genera preguntas de práctica y descarta las inválidas', async () => {
  iaFalsa.respuesta = () => JSON.stringify({
    preguntas: [
      { enunciado: '¿Cuánto es lim x→0 sen(x)/x?', opciones: ['0', '1', '∞', 'No existe'], correcta: 1, explicacion: 'Límite notable.', tema: 'Límites notables' },
      { enunciado: 'Pregunta con la respuesta fuera de rango', opciones: ['a', 'b'], correcta: 5, explicacion: '...', tema: 'x' },
    ],
  });
  const res = await pedir('POST', `/api/materiales/${t.tallerFisica}/ia/practica`, { token: t.ana });
  assert.equal(res.status, 201);
  assert.equal(res.body.contenido.preguntas.length, 1);
  assert.equal(res.body.contenido.preguntas[0].correcta, 1);
});

test('RF-16: el estudiante conversa con el Tutor IA sobre el material', async () => {
  iaFalsa.respuesta = () => 'Primero factorice el numerador.';
  const res = await pedir('POST', `/api/materiales/${t.parcialCalculo}/ia/preguntas`, {
    token: t.ana,
    body: {
      pregunta: '¿Cómo empiezo el punto 2?',
      historial: [
        { rol: 'estudiante', texto: '¿De qué trata el parcial?' },
        { rol: 'tutor', texto: 'De límites y derivadas.' },
      ],
    },
  });
  assert.equal(res.status, 200);
  assert.equal(res.body.respuesta, 'Primero factorice el numerador.');
  assert.equal(res.body.fuente, 'archivo');

  // Los turnos alternan: el material y la primera pregunta van juntos en el primer turno.
  const { mensajes } = iaFalsa.peticiones.at(-1);
  assert.deepEqual(mensajes.map((m) => m.rol), ['usuario', 'modelo', 'usuario']);
  assert.equal(mensajes[0].partes.at(-1).texto, '¿De qué trata el parcial?');
  assert.equal(mensajes.at(-1).partes[0].texto, '¿Cómo empiezo el punto 2?');
  // R-11: la conversación no se guarda en la base de datos.
  const { rows } = await pool.query('SELECT tipo FROM ia_contenidos');
  assert.ok(rows.every((r) => r.tipo !== 'preguntas'));
});

test('RF-16: el Tutor IA informa cuando declina responder o el material no existe', async () => {
  iaFalsa.respuesta = () => { throw new tutor.ErrorIa(422, 'La IA no puede responder esta solicitud.'); };
  const declinada = await pedir('POST', `/api/materiales/${t.parcialCalculo}/ia/preguntas`, {
    token: t.ana, body: { pregunta: 'Algo que el modelo no responde' },
  });
  assert.equal(declinada.status, 422);
  assert.ok(declinada.body.error);

  const inexistente = await pedir('POST', '/api/materiales/999999/ia/explicacion', { token: t.ana });
  assert.equal(inexistente.status, 404);
});

const revisionIa = (cambios = {}) => JSON.stringify({
  veredicto: 'aprobado',
  motivo: 'Es un parcial de límites con soluciones.',
  es_material_academico: true,
  coincide_con_asignatura: true,
  coincide_con_titulo: true,
  legible: true,
  contenido_inapropiado: false,
  datos_personales: false,
  tipo: 'parcial',
  temas: ['Límites', 'Continuidad'],
  dificultad: 'media',
  resumen: 'Cinco ejercicios de límites y continuidad resueltos.',
  ...cambios,
});

test('RF-17/RF-19: la IA aprueba el material al subirlo y se crea su vista previa', async () => {
  iaFalsa.respuesta = () => revisionIa();
  const res = await subir(t.beto, {
    titulo: 'Parcial de límites 2026-2', asignatura_id: t.calculo,
  }, { contenido: pdfDePrueba, nombre: 'parcial.pdf' });
  assert.equal(res.status, 201);
  assert.equal(res.body.estado, 'publicado');
  assert.equal(res.body.revision_ia.veredicto, 'aprobado');
  assert.equal(res.body.revision_ia.tipo, 'parcial');
  assert.deepEqual(res.body.revision_ia.temas, ['Límites', 'Continuidad']);
  assert.equal(res.body.revision_ia.modelo, 'falsa:modelo-de-prueba');
  // La revisión recibe el archivo y la asignatura elegida.
  const peticion = iaFalsa.peticiones.at(-1);
  assert.equal(peticion.mensajes[0].partes[0].archivo.mimeType, 'application/pdf');
  assert.ok(peticion.mensajes[0].partes[1].texto.includes('Cálculo'));
  // RF-19: la miniatura es un JPG en UPLOADS_DIR.
  assert.match(res.body.miniatura_url, /^\/uploads\/.+-miniatura\.jpg$/);
  const miniatura = await fetch(base + res.body.miniatura_url);
  assert.equal(miniatura.status, 200);
  assert.equal(miniatura.headers.get('content-type'), 'image/jpeg');
  t.parcialAprobado = res.body.id;

  // El tipo que identificó la IA sirve para filtrar el material.
  const parciales = await pedir('GET', '/api/materiales?tipo=parcial', { token: t.ana });
  assert.ok(parciales.body.some((m) => m.id === t.parcialAprobado));
});

test('RF-17/R-14: la IA rechaza lo que no es académico o no corresponde a la asignatura', async () => {
  const antes = fs.readdirSync(uploadsDir).length;
  for (const cambios of [
    { es_material_academico: false, veredicto: 'rechazado', motivo: 'Es publicidad de una pizzería.' },
    // Aunque el modelo diga «aprobado», el servidor rechaza si no coincide la asignatura.
    { coincide_con_asignatura: false, motivo: 'Es una guía de química, no de Cálculo.' },
    { legible: false },
    { contenido_inapropiado: true },
  ]) {
    iaFalsa.respuesta = () => revisionIa(cambios);
    const res = await subir(t.beto, { titulo: 'Material', asignatura_id: t.calculo });
    assert.equal(res.status, 422, JSON.stringify(cambios));
    assert.equal(res.body.revision.veredicto, 'rechazado');
    assert.ok(res.body.error.startsWith('La IA no aprobó el material'));
  }
  // El archivo rechazado no queda en el servidor ni en la base de datos.
  await new Promise((r) => setTimeout(r, 100));
  assert.equal(fs.readdirSync(uploadsDir).length, antes);
  const { rows } = await pool.query(`SELECT 1 FROM materiales WHERE titulo = 'Material'`);
  assert.equal(rows.length, 0);
});

test('RF-17: el material dudoso queda pendiente y solo lo ven su autor y el administrador', async () => {
  iaFalsa.respuesta = () => revisionIa({ coincide_con_titulo: false, motivo: 'El título no describe el contenido.' });
  const res = await subir(t.beto, { titulo: 'Cosas varias', asignatura_id: t.calculo });
  assert.equal(res.status, 201);
  assert.equal(res.body.estado, 'pendiente');
  const pendiente = res.body.id;

  const listaAna = await pedir('GET', '/api/materiales', { token: t.ana });
  assert.ok(!listaAna.body.some((m) => m.id === pendiente), 'otro estudiante no lo ve');
  assert.equal((await pedir('GET', `/api/materiales/${pendiente}`, { token: t.ana })).status, 404);

  const mios = await pedir('GET', '/api/materiales?mios=true', { token: t.beto });
  const propio = mios.body.find((m) => m.id === pendiente);
  assert.ok(propio, 'su autor lo ve en «Mis aportes»');
  assert.equal(propio.es_mio, true);
  assert.equal(propio.revision_ia.motivo, 'El título no describe el contenido.');
  assert.ok(mios.body.every((m) => m.es_mio));

  const admin = await pedir('GET', '/api/materiales?estado=pendiente', { token: t.admin });
  assert.ok(admin.body.some((m) => m.id === pendiente));
  // El administrador lo aprueba y queda visible para todos.
  await pedir('PUT', `/api/materiales/${pendiente}`, { token: t.admin, body: { estado: 'publicado' } });
  assert.equal((await pedir('GET', `/api/materiales/${pendiente}`, { token: t.ana })).status, 200);

  // Si la IA falla, el material no se pierde: queda pendiente para el administrador.
  iaFalsa.respuesta = () => { throw new tutor.ErrorIa(429, 'Se alcanzó el límite gratuito de la IA por ahora.'); };
  const sinIa = await subir(t.beto, { titulo: 'Parcial subido sin IA', asignatura_id: t.calculo });
  assert.equal(sinIa.status, 201);
  assert.equal(sinIa.body.estado, 'pendiente');
  assert.ok(sinIa.body.revision_ia.motivo.includes('límite gratuito'));
});

test('RF-18: simulacro de parcial con el material de la asignatura', async () => {
  iaFalsa.respuesta = () => JSON.stringify({
    preguntas: [
      { enunciado: '¿Cuánto es lim x→2 (x^2 - 4)/(x - 2)?', opciones: ['0', '2', '4', 'No existe'], correcta: 2, explicacion: 'Se factoriza.', tema: 'Límites' },
    ],
  });
  const res = await pedir('POST', `/api/asignaturas/${t.calculo}/ia/simulacro`, {
    token: t.ana, body: { preguntas: 5 },
  });
  assert.equal(res.status, 200);
  assert.equal(res.body.contenido.preguntas.length, 1);
  assert.ok(res.body.materiales_usados >= 1);
  const peticion = iaFalsa.peticiones.at(-1);
  assert.ok(peticion.mensajes[0].partes.at(-1).texto.includes('simulacro de parcial de 5 preguntas'));
  // Solo usa material publicado: el pendiente no se envía.
  assert.ok(!JSON.stringify(peticion).includes('Parcial subido sin IA'));

  const sinMaterial = await pedir('POST', `/api/asignaturas/${t.quimica}/ia/simulacro`, { token: t.ana });
  assert.ok([404, 409].includes(sinMaterial.status));
});

test('R-13: cada usuario tiene un límite de consultas nuevas al Tutor IA por hora', async () => {
  iaCtrl.reiniciarLimites();
  iaFalsa.respuesta = () => 'Respuesta.';
  for (let i = 0; i < iaCtrl.LIMITE_POR_HORA; i += 1) {
    const res = await pedir('POST', `/api/materiales/${t.parcialCalculo}/ia/preguntas`, {
      token: t.beto, body: { pregunta: `Pregunta ${i}` },
    });
    assert.equal(res.status, 200);
  }
  const excedida = await pedir('POST', `/api/materiales/${t.parcialCalculo}/ia/preguntas`, {
    token: t.beto, body: { pregunta: 'Una más' },
  });
  assert.equal(excedida.status, 429);
  // El límite es por usuario, y la explicación guardada no cuenta como consulta.
  const otroUsuario = await pedir('POST', `/api/materiales/${t.parcialCalculo}/ia/preguntas`, {
    token: t.ana, body: { pregunta: 'Mi pregunta' },
  });
  assert.equal(otroUsuario.status, 200);
  const guardada = await pedir('POST', `/api/materiales/${t.parcialCalculo}/ia/explicacion`, { token: t.beto });
  assert.equal(guardada.status, 200);
  iaCtrl.reiniciarLimites();
  tutor.usarProveedor(null);
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
