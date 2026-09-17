# Plataforma de Apoyo Académico

Proyecto de aula — curso de Ingeniería de Software.
Equipo: **Jaime Mochen** y **Cristian David Cardeño Gulloso**.

Plataforma web que permite a los estudiantes universitarios centralizar, organizar y
consultar material de estudio (parciales anteriores, talleres y otros recursos),
clasificado por asignatura, semestre y tema, para facilitar la práctica autónoma y el
refuerzo de conocimientos antes de las evaluaciones.

> 📄 El documento completo del proyecto —descripción del problema, interesados, técnicas
> de elicitación, requerimientos, priorización y validación del modelado— está en
> [`docs/Avance_de_proyecto_de_aula_Plataforma_de_Apoyo_Academico.pdf`](docs/Avance_de_proyecto_de_aula_Plataforma_de_Apoyo_Academico.pdf).

## Estado de este repositorio

Este repositorio se inicia con un **scaffold funcional del MVP**: la API backend está
implementada y probada de extremo a extremo para los requerimientos "Obligatorio" del
documento (registro/login, búsqueda y filtro de material, carga con opción anónima,
valoración, reporte de contenido y su revisión por el administrador). El frontend
Flutter Web tiene la estructura y las pantallas del mismo flujo, lista para conectarse
al backend.

**Importante para el equipo:** a partir de este punto, el historial de commits debe
reflejar el trabajo real del equipo (confirmaciones claras y frecuentes, como pide el
enunciado de la actividad) — no se generaron commits simulados con fechas o mensajes
ficticios.

## Arquitectura

```
Estudiante / Administrador
        │  HTTPS
        ▼
 Aplicación Flutter Web  ───►  Backend API (Node.js + Express)  ───►  PostgreSQL
                                          │
                                          └──► Almacenamiento de archivos (local en
                                               desarrollo; /uploads en el backend)
```

Ver los diagramas completos en [`docs/diagramas/`](docs/diagramas/) (casos de uso,
clases, secuencia, actividades, componentes y despliegue — los dos primeros ya
actualizados con los hallazgos de la sección 8 del documento).

### Modelo de datos

`Usuario` (Estudiante / Administrador) — `Asignatura` — `Material` — `Valoracion` —
`Reporte`. El esquema SQL completo, con los mismos nombres y relaciones del diagrama de
clases, está en [`backend/src/db/schema.sql`](backend/src/db/schema.sql).

## Requerimientos cubiertos por este scaffold

| ID | Requerimiento | Dónde |
|----|----------------|-------|
| RF-01 | Registro de usuario | `POST /api/auth/registro` |
| RF-02 | Inicio / cierre de sesión (JWT) | `POST /api/auth/login` |
| RF-03 | Búsqueda de material por asignatura | `GET /api/materiales?asignatura_id=` |
| RF-04 | Filtro por semestre / tema | `GET /api/materiales?semestre=&q=` |
| RF-05 | Visualizar y descargar material | `GET /api/materiales/:id`, `/uploads/...` |
| RF-06 | Carga de material por estudiantes | `POST /api/materiales` |
| RF-07 | Carga anónima | campo `es_anonimo` (oculta el autor en las respuestas) |
| RF-08 | Valoración y comentarios | `POST /api/materiales/:id/valoraciones` |
| RF-09 | Reporte de contenido | `POST /api/materiales/:id/reportes` |
| RF-10 | Revisión de reportes | `GET/PATCH /api/reportes` (solo administrador) |
| RF-11 | Metadatos de vigencia (profesor, periodo) | columnas `profesor`, `periodo_academico` |
| RF-12 | Gestión de material (admin) | `PUT/DELETE /api/materiales/:id` |
| RF-13 | Gestión de usuarios / asignaturas | `/api/usuarios`, `/api/asignaturas` |
| RNF-04 | Seguridad (contraseña cifrada, rutas por rol) | `bcryptjs` + middleware `requiereRol` |
| RNF-07 | Acceso gratuito | sin flujo de pago en ninguna ruta |

Los requerimientos "Importante"/"Deseable" (RNF-01, 02, 03, 05, 06) quedan como trabajo
siguiente del equipo; el diseño actual (arquitectura por capas, estados de material) no
los bloquea.

## Backend (Node.js + Express + PostgreSQL)

```bash
cd backend
cp .env.example .env        # complete DB_USER, DB_PASSWORD, JWT_SECRET, etc.
npm install
npm run migrate             # aplica backend/src/db/schema.sql
npm run dev                 # http://localhost:4000
```

Verificación rápida:

```bash
curl http://localhost:4000/api/salud
# {"estado":"ok","servicio":"plataforma-apoyo-academico-api"}
```

Esta API ya fue probada de extremo a extremo (registro, login, control de acceso por
rol, búsqueda, carga de archivo real, valoración, reporte y resolución de reporte) antes
de subirla al repositorio.

## Frontend (Flutter Web)

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:4000
```

> Este scaffold se escribió sin el SDK de Flutter disponible en el entorno donde se
> generó, por lo que **no se ejecutó `flutter pub get` / `flutter analyze` todavía**.
> Es el primer paso que debe hacer el equipo al continuar: corran `flutter pub get` y
> `flutter run -d chrome`, y ajusten lo que el analizador señale (nombres de API que
> hayan cambiado de versión, por ejemplo). El código sigue los patrones estándar de
> Flutter (Provider para el estado de sesión, `http` para consumir la API, `file_picker`
> para adjuntar archivos), así que los ajustes esperables son menores.

Pantallas incluidas: inicio de sesión, registro, búsqueda/listado de material (con
subida desde un botón flotante), detalle de material (descargar, valorar, reportar), y
para el rol administrador: gestionar material y revisar reportes.

## Convención de commits

```
tipo(alcance): descripción breve

feat(material): agregar carga anónima de material
fix(auth): corregir validación de contraseña
docs(readme): actualizar instrucciones de despliegue
```

Tipos sugeridos: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`.

## Estructura del repositorio

```
plataforma-apoyo-academico/
├── docs/                    # documento del proyecto + diagramas UML
├── backend/                 # API REST (Node.js + Express + PostgreSQL)
│   └── src/
│       ├── config/          # conexión a la base de datos
│       ├── db/              # schema.sql + script de migración
│       ├── middleware/      # autenticación, roles, subida de archivos, errores
│       ├── controllers/     # lógica de cada recurso (auth, materiales, ...)
│       └── routes/          # definición de endpoints
└── frontend/                # cliente Flutter Web
    └── lib/
        ├── config/          # URL base de la API
        ├── models/          # Usuario, Asignatura, Material, Valoracion, Reporte
        ├── services/        # cliente HTTP hacia el backend
        ├── state/           # sesión (usuario/token) con Provider
        ├── screens/         # pantallas de la aplicación
        └── widgets/         # componentes reutilizables
```

## Próximos pasos sugeridos

1. Ejecutar `flutter pub get` / `flutter analyze` y corregir lo que señale.
2. Desplegar un PostgreSQL de desarrollo compartido por el equipo (o usar uno local por
   integrante) y ajustar `backend/.env`.
3. Configurar el tablero de gestión del proyecto (ver sección 9.2 del documento) con el
   backlog inicial: los requerimientos de la tabla de arriba, ya priorizados.
4. Habilitar el acceso del docente al repositorio si se mantiene privado.
