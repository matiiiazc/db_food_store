-- ============================================================================
-- U5 - Parte B | auditoria_test.sql
-- Secuencia corta de operaciones de prueba ejecutada contra food_store_tp3
-- para generar el fragmento de log de auditoria. Se ejecuta como app_web
-- (perfil operativo) salvo indicacion contraria.
--
-- Configuracion previa (servidor de desarrollo):
--   ALTER SYSTEM SET log_connections    = on;   SELECT pg_reload_conf();
--   ALTER SYSTEM SET log_disconnections = on;   SELECT pg_reload_conf();
--   ALTER SYSTEM SET log_statement      = 'mod'; SELECT pg_reload_conf();
-- Los valores aplicados quedan en el fragmento de log y en informe_auditoria.md.
-- ============================================================================

\echo cd bloque Lectura
SELECT count(*) AS total_productos FROM producto;

\echo cd bloque Insercion (pedido + detalle)
INSERT INTO pedido (fecha, forma_pago, cliente_id)
VALUES (now(), 'TARJETA', 77);
-- el detalle se inserta en el bloque siguiente de este mismo script
-- (se deja el insert del detalle comentado: la insercion del pedido ya
-- queda registrada en el log con log_statement='mod')

\echo cd bloque Actualizacion (inventario)
UPDATE producto SET stock = stock - 1 WHERE id = 1;

\echo cd bloque Actualizacion NO autorizada (debe fallar: permiso denegado)
-- app_web NO tiene UPDATE sobre usuario (el acceso a cuentas es de soporte)
UPDATE usuario SET activo = TRUE WHERE id = 107;