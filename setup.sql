-- ============================================================
-- FOOD STORE — setup.sql
-- Crea las bases de datos plantilla_base y copia_trabajo
-- ============================================================
-- Ejecutar una sola vez desde la terminal:
--   psql -f setup.sql
-- ============================================================


-- 1. Crear la plantilla (si no existe)
SELECT 'CREATE DATABASE plantilla_base'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'plantilla_base')\gexec

-- 2. Aplicar el esquema a la plantilla
\echo 'Aplicando schema.sql a plantilla_base...'
\! psql -d plantilla_base -f schema.sql

-- 3. Crear la copia de trabajo desde la plantilla
SELECT 'DROP DATABASE IF EXISTS copia_trabajo'
WHERE EXISTS (SELECT FROM pg_database WHERE datname = 'copia_trabajo')\gexec

\echo 'Creando copia_trabajo desde plantilla_base...'
\! createdb -T plantilla_base copia_trabajo

\echo 'Listo. Bases creadas: plantilla_base, copia_trabajo'
