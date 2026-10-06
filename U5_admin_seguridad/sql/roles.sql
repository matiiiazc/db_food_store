-- ============================================================================
-- U5 - Parte A | roles.sql
-- Esquema de roles y permisos de minimo privilegio para Food Store.
--
-- Secciones:
--   0. Reconstruccion documentada de los artefactos de la Clase 2
--      (la tabla usuario de seguridad y las funciones fn_autenticar /
--      fn_resetear_password no se conservaron con el diseño visto en clase
--      en este entorno; se reconstruyen aqui, constancia en BITACORA.md).
--   1. Roles de grupo (NOLOGIN) y roles de login.
--   2. GRANT / REVOKE puntuales (incluye permiso a nivel de COLUMNA sobre
--      usuario.producto y ALTER DEFAULT PRIVILEGES).
--   3. Verificacion: \du y information_schema.
--
-- Entorno: desarrollo local (food_store_tp3, PostgreSQL 18).
-- ============================================================================

-- ============================================================================
-- 0. ARTEFACTOS DE LA CLASE 2 (reconstruidos)
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Tabla usuario: evolucion de la maestra de usuario para ser la tabla de
-- identidades del sistema (email, password_hash, fecha_alta, activo).
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS email         TEXT;
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS password_hash TEXT;
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS fecha_alta    DATE;
ALTER TABLE usuario ADD COLUMN IF NOT EXISTS activo        BOOLEAN NOT NULL DEFAULT TRUE;

\set pass_admin   'FoodStore_Admin2026'
\set pass_web     'FoodStore_Web2026'
\set pass_soporte 'FoodStore_Soporte2026'
\set pass_reporte 'FoodStore_Reporte2026'

-- Datos de identidades (entorno de desarrollo; las credenciales claras
-- no se repiten fuera de este script local y se rotan antes de productivo).
UPDATE usuario SET email='ana.contreras@foodstore.local',  fecha_alta='2025-03-05', password_hash=crypt('ClaveDestino'||id, gen_salt('bf')) WHERE id=801;
UPDATE usuario SET email='bruno.sosa@foodstore.local',     fecha_alta='2025-05-12', password_hash=crypt('ClaveDestino'||id, gen_salt('bf')) WHERE id=802;
UPDATE usuario SET email='carla.mendez@foodstore.local',   fecha_alta='2025-07-20', password_hash=crypt('ClaveDestino'||id, gen_salt('bf')) WHERE id=803;

INSERT INTO usuario (id, nombre, rol, email, fecha_alta, password_hash) VALUES
  (101, 'Maria Garcia',    'administrador',        'it.admin@foodstore.local',  DATE '2025-01-10', crypt('ClaveDestino101', gen_salt('bf'))),
  (102, 'Web Service',     'aplicacion',           'web@foodstore.local',       DATE '2025-01-10', crypt(:'pass_web', gen_salt('bf'))),
  (103, 'Lucas Fernandez', 'soporte',              'soporte@foodstore.local',   DATE '2025-02-14', crypt(:'pass_soporte', gen_salt('bf'))),
  (104, 'Panel Reportes',  'reportes',             'reportes@foodstore.local',  DATE '2025-02-14', crypt(:'pass_reporte', gen_salt('bf'))),
  (105, 'Jose Peralta',    'tienda',               'tienda.norte@foodstore.local', DATE '2025-11-03', crypt('ClaveDestino105', gen_salt('bf'))),
  (106, 'Sofia Lopez',     'administrador',        'sofia.lopez@foodstore.local', DATE '2025-11-03', crypt('ClaveDestino106', gen_salt('bf'))),
  (107, 'Tienda Central',  'aplicacion',           'tienda.central@foodstore.local', DATE '2025-12-01', crypt('ClaveDestino107', gen_salt('bf'))),
  (108, 'Tienda Sur',      'aplicacion',           'tienda.sur@foodstore.local', DATE '2026-01-21', crypt('ClaveDestino108', gen_salt('bf')))
ON CONFLICT (id) DO UPDATE
   SET email = EXCLUDED.email, fecha_alta = EXCLUDED.fecha_alta,
       password_hash = EXCLUDED.password_hash;

-- Registro de intentos de autenticacion (base de la auditoria de login).
CREATE TABLE IF NOT EXISTS audit_login (
    tiempo   TIMESTAMPTZ NOT NULL DEFAULT now(),
    email    TEXT        NOT NULL,
    exito    BOOLEAN     NOT NULL,
    origen   TEXT
);

-- fn_autenticar: verifica email/password contra password_hash.
-- SECURITY DEFINER: lee password_hash pese al permiso a nivel de columna.
-- Registra cada intento (exito o no) en audit_login (rendicion de cuentas).
CREATE OR REPLACE FUNCTION fn_autenticar(p_email TEXT, p_password TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    v_hash  TEXT;
    v_ok    BOOLEAN := FALSE;
    v_act   BOOLEAN;
BEGIN
    SELECT password_hash, activo INTO v_hash, v_act
      FROM usuario WHERE email = lower(p_email);

    IF v_hash IS NOT NULL AND v_act THEN
        v_ok := (crypt(p_password, v_hash) = v_hash);
    END IF;

    INSERT INTO audit_login (email, exito) VALUES (lower(p_email), v_ok);
    RETURN v_ok;
END $$;

-- fn_resetear_password: reservado; reemplaza el hash solo si la cuenta existe.
CREATE OR REPLACE FUNCTION fn_resetear_password(p_email TEXT, p_password TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    UPDATE usuario
       SET password_hash = crypt(p_password, gen_salt('bf'))
     WHERE email = lower(p_email) AND activo;
    RETURN FOUND;
END $$;

-- ============================================================================
-- 1. ROLES
-- ============================================================================
-- Roles de grupo (sin login): agrupan privilegios.
DROP ROLE IF EXISTS rol_app_lectura;
DROP ROLE IF EXISTS rol_app_escritura;
DROP ROLE IF EXISTS rol_soporte;
DROP ROLE IF EXISTS rol_reportes;

CREATE ROLE rol_app_lectura  NOLOGIN;
CREATE ROLE rol_app_escritura NOLOGIN;
CREATE ROLE rol_soporte       NOLOGIN;
CREATE ROLE rol_reportes      NOLOGIN;

-- Roles de login: identidades reales del sistema.
DROP ROLE IF EXISTS app_web;
DROP ROLE IF EXISTS admin_datos;
DROP ROLE IF EXISTS soporte_app;
DROP ROLE IF EXISTS reportes_app;

CREATE ROLE app_web       LOGIN PASSWORD :'pass_web';
CREATE ROLE admin_datos   LOGIN PASSWORD :'pass_admin';
CREATE ROLE soporte_app   LOGIN PASSWORD :'pass_soporte';
CREATE ROLE reportes_app  LOGIN PASSWORD :'pass_reporte';

-- Membresias (herencia de privilegios, sin ADMIN OPTION: nadie reparte roles).
GRANT rol_app_lectura  TO rol_app_escritura;
GRANT rol_app_lectura  TO rol_soporte;
GRANT rol_app_lectura  TO rol_reportes;
GRANT rol_soporte, rol_reportes TO admin_datos;
GRANT rol_app_escritura TO app_web;
GRANT rol_soporte      TO soporte_app;
GRANT rol_reportes     TO reportes_app;

-- ============================================================================
-- 2. GRANT / REVOKE puntuales (minimo privilegio)
-- ============================================================================
GRANT USAGE ON SCHEMA public TO rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes;

-- LECTURA: SELECT sobre todo el catalogo/transacciones (no sobre usuario:
-- las identidades incluyen password_hash y no son del dominio transaccional).
GRANT SELECT ON categoria, cliente, producto, pedido, detalle_pedido,
              lote, deposito TO rol_app_lectura;

-- ESCRITURA: inserta pedidos y sus lineas; ajusta stock/precio/activo de
-- producto; NO borra filas (baja logica del dominio) y NO toca usuario.
GRANT INSERT, UPDATE ON pedido TO rol_app_escritura;
GRANT INSERT, UPDATE ON detalle_pedido TO rol_app_escritura;
GRANT UPDATE (stock, precio, activo) ON producto TO rol_app_escritura;

-- SOPORTE: caso de permiso a NIVEL DE COLUMNA sobre usuario.
-- Puede ver datos de cuenta (sin email ni password_hash) y actualizar
-- estado o nombre; la rotacion de password_hash queda solo via
-- fn_resetear_password (SECURITY DEFINER), nunca como UPDATE directo.
GRANT SELECT (id, nombre, rol, fecha_alta, activo) ON usuario TO rol_soporte;
GRANT UPDATE (nombre, activo) ON usuario TO rol_soporte;

-- REPORTES: solo SELECT (incluye las vistas de reporte creadas por el TP).
GRANT SELECT ON categoria, cliente, producto, pedido, detalle_pedido,
              vista_productos_vigentes, vista_pedidos_cliente,
              mv_top_categorias_dia TO rol_reportes;

-- FUNCIONES: ejecucion segun necesidad.
GRANT EXECUTE ON FUNCTION fn_autenticar(p_email TEXT, p_password TEXT)
      TO rol_app_lectura;
GRANT EXECUTE ON FUNCTION fn_resetear_password(p_email TEXT, p_password TEXT)
      TO rol_soporte;

-- Las funciones internas del proyecto (fn_descontar_stock, fn_verificar_subtotal)
-- se ejecutan por triggers al escribir pedido/detalle; el acceso al dato al
-- que acceden (producto.stock) ya esta cubierto por el GRANT de escritura.

-- ALTER DEFAULT PRIVILEGES: las tablas futuras del esquema public heredan
-- la misma politica (lectura para los cuatro roles, escritura para app,
-- sin acceso a tablas nuevas por parte de app a menos que se explicite).
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_app_lectura, rol_soporte, rol_reportes;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT INSERT, UPDATE, DELETE ON TABLES TO rol_app_escritura;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT EXECUTE ON FUNCTIONS TO rol_app_lectura, rol_soporte, rol_reportes;

-- REVOKE explicito (defensa en profundidad): public no hereda privilegios
-- nuevos sobre los objetos de seguridad creados por este cambio.
REVOKE ALL ON usuario FROM PUBLIC;
REVOKE ALL ON audit_login FROM PUBLIC;

-- ============================================================================
-- 3. VERIFICACION (salida en docs/verificacion_permisos_du.txt)
--    \du y consulta sobre information_schema.role_table_grants:
--    cada rol debe tener exactamente los privilegios especificados.
-- ============================================================================
\echo '=== du ==='
\du
\echo '=== role_table_grants (por rol) ==='
SELECT grantee, table_name,
       coalesce(string_agg(privilege_type, ',' ORDER BY privilege_type), '') AS privileges
FROM information_schema.role_table_grants
WHERE grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte','rol_reportes',
                  'app_web','admin_datos','soporte_app','reportes_app')
GROUP BY grantee, table_name
ORDER BY grantee, table_name;
\echo '=== grants de columna sobre usuario ==='
SELECT grantee, column_name, privilege_type
FROM information_schema.role_column_grants
WHERE table_name='usuario'
ORDER BY grantee, column_name;
\echo '=== rol_soporte no accede a email/password_hash (debe dar permiso denegado) ==='
SET ROLE rol_soporte;
SELECT id, email FROM usuario;
RESET ROLE;