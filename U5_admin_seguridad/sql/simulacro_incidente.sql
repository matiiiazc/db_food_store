-- ============================================================================
-- U5 - Parte C | simulacro_incidente.sql
-- LABORATORIO CONTROLADO (entorno de desarrollo local food_store_tp3).
-- Reproduce, contra la PROPIA base, la secuencia de un acceso indebido:
--   1) varios intentos fallidos de inicio de sesion (fn_autenticar)
--   2) un inicio de sesion exitoso
--   3) una lectura masiva de la tabla usuario
--   4) un intento de escalamiento: otorgar membresia en admin_datos
-- Se ejecuta como app_web (rol de bajo privilegio). La verificacion de que
-- el escalamiento FALLA (punto 2 de la consigna) queda al final del script.
--
-- Credenciales: entorno de desarrollo local; el hash se genera con pgcrypto.
-- ============================================================================

\set pwd_falla 'ClaveEquivocada_NoEsEsta'
\set pwd_ok    'FoodStore_Web2026'

\echo ============ PASO 1: 7 intentos fallidos de login ============
SELECT fn_autenticar('web@foodstore.local', :'pwd_falla') AS login_1_falla;
SELECT fn_autenticar('web@foodstore.local', :'pwd_falla') AS login_2_falla;
SELECT fn_autenticar('web@foodstore.local', :'pwd_falla') AS login_3_falla;
SELECT fn_autenticar('web@foodstore.local', :'pwd_falla') AS login_4_falla;
SELECT fn_autenticar('web@foodstore.local', :'pwd_falla') AS login_5_falla;
SELECT fn_autenticar('web@foodstore.local', :'pwd_falla') AS login_6_falla;
SELECT fn_autenticar('web@foodstore.local', :'pwd_falla') AS login_7_falla;

\echo ============ PASO 2: un inicio de sesion exitoso ============
SELECT fn_autenticar('web@foodstore.local', :'pwd_ok') AS login_ok;

\echo ============ PASO 3: lectura masiva de la tabla usuario ============
\echo (app_web NO tiene SELECT sobre usuario: esto debe FALLAR por permisos)
SELECT * FROM usuario;

\echo ============ PASO 4: intento de escalamiento ============
\echo (app_web no tiene ADMIN OPTION: esto debe FALLAR y quedar en el log)
GRANT admin_datos TO app_web;

\echo ============ VERIFICACION: el escalamiento NO procedio ============
SELECT EXISTS (
    SELECT 1
      FROM pg_auth_members m
      JOIN pg_roles r ON r.oid = m.roleid
      JOIN pg_roles u ON u.oid = m.member
     WHERE r.rolname = 'admin_datos'
       AND u.rolname = 'app_web'
) AS app_web_sigue_sin_ser_admin;

\echo ============ EVIDENCIA: intentos registrados en audit_login ============
SELECT to_char(tiempo, 'YYYY-MM-DD HH24:MI:SS') AS instante,
       email, exito
FROM audit_login
ORDER BY tiempo DESC
LIMIT 10;