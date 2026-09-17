-- Esquema de base de datos — Plataforma de Apoyo Académico
-- Corresponde al diagrama de clases actualizado (docs/diagramas/02-clases.png).
-- Incluye los ajustes descritos en la sección 8 del "Avance de proyecto de aula":
--   - Material: profesor, periodo_academico, es_anonimo, estado
--   - Nueva tabla: reportes

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- para gen_random_uuid(), si se requiere en el futuro

-- ---------------------------------------------------------------- usuarios
-- Representa la superclase Usuario; el rol determina si es Estudiante o Administrador.
CREATE TABLE IF NOT EXISTS usuarios (
    id              SERIAL PRIMARY KEY,
    nombre          VARCHAR(120)  NOT NULL,
    correo          VARCHAR(180)  NOT NULL UNIQUE,
    contrasena_hash VARCHAR(255)  NOT NULL,
    rol             VARCHAR(20)   NOT NULL DEFAULT 'estudiante'
                        CHECK (rol IN ('estudiante', 'administrador')),
    creado_en       TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------- asignaturas
CREATE TABLE IF NOT EXISTS asignaturas (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(150) NOT NULL,
    codigo      VARCHAR(30)  NOT NULL UNIQUE,
    semestre    VARCHAR(30)  NOT NULL,
    creado_en   TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------- materiales
-- RF-06/RF-07: carga (anónima o no); RF-11: metadatos de vigencia (profesor, periodo);
-- "estado" soporta RF-09/RF-10 (publicado -> reportado -> en_revision -> publicado/retirado).
CREATE TABLE IF NOT EXISTS materiales (
    id                  SERIAL PRIMARY KEY,
    titulo              VARCHAR(200) NOT NULL,
    descripcion         TEXT,
    archivo_url         VARCHAR(500) NOT NULL,
    fecha_publicacion   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    profesor            VARCHAR(150),
    periodo_academico   VARCHAR(30),
    es_anonimo          BOOLEAN      NOT NULL DEFAULT false,
    estado              VARCHAR(20)  NOT NULL DEFAULT 'publicado'
                            CHECK (estado IN ('publicado', 'reportado', 'en_revision', 'retirado')),
    asignatura_id       INTEGER      NOT NULL REFERENCES asignaturas(id) ON DELETE RESTRICT,
    usuario_id          INTEGER      NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    creado_en           TIMESTAMPTZ  NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_materiales_asignatura ON materiales(asignatura_id);
CREATE INDEX IF NOT EXISTS idx_materiales_estado ON materiales(estado);

-- ---------------------------------------------------------------- valoraciones
-- RF-08: calificación (1-5) y comentario de un estudiante sobre un material.
CREATE TABLE IF NOT EXISTS valoraciones (
    id          SERIAL PRIMARY KEY,
    puntuacion  SMALLINT     NOT NULL CHECK (puntuacion BETWEEN 1 AND 5),
    comentario  TEXT,
    material_id INTEGER      NOT NULL REFERENCES materiales(id) ON DELETE CASCADE,
    usuario_id  INTEGER      NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    creado_en   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    UNIQUE (material_id, usuario_id) -- un estudiante valora un material una sola vez
);

-- ---------------------------------------------------------------- reportes
-- RF-09/RF-10: clase nueva incorporada en la validación del modelado (sección 8.4).
CREATE TABLE IF NOT EXISTS reportes (
    id          SERIAL PRIMARY KEY,
    motivo      VARCHAR(500) NOT NULL,
    estado      VARCHAR(20)  NOT NULL DEFAULT 'pendiente'
                    CHECK (estado IN ('pendiente', 'resuelto', 'descartado')),
    material_id INTEGER      NOT NULL REFERENCES materiales(id) ON DELETE CASCADE,
    usuario_id  INTEGER      NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    creado_en   TIMESTAMPTZ  NOT NULL DEFAULT now(),
    resuelto_en TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_reportes_estado ON reportes(estado);
