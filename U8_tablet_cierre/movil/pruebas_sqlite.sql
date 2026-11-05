-- Food Store - pruebas_sqlite.sql (Consigna 1.c)
-- Ejecutar sobre una base creada con schema_sqlite.sql.
PRAGMA foreign_keys = ON;

-- Semilla mínima de catálogo (copia local inventada, para pruebas sin servidor)
INSERT INTO producto_cache (id,nombre,precio_centavos,stock_visto,disponible,eliminado,fecha_copia) VALUES
  (1,'Producto 1',124984,164,1,0,'2026-11-05T10:00:00Z'),
  (2,'Producto 2',308614,133,1,0,'2026-11-05T10:00:00Z'),
  (5,'Producto 5',493511, 37,1,0,'2026-11-05T10:00:00Z');

-- (1) Borrador completo guardado con BEGIN..COMMIT
BEGIN;
INSERT INTO pedido_borrador (id_local,usuario,forma_pago,fecha)
  VALUES ('11111111-1111-4111-8111-111111111111','vend_feria_1','EFECTIVO','2026-11-05T10:15:00Z');
INSERT INTO item_borrador (id_local,producto_id,cantidad,precio_centavos_visto)
  VALUES ('11111111-1111-4111-8111-111111111111', 1, 2, 124984),
         ('11111111-1111-4111-8111-111111111111', 2, 1, 308614);
INSERT INTO cola_sync (solicitud_uuid,id_local,estado,motivo)
  VALUES ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','PENDIENTE',NULL);
COMMIT;

-- Verificación: el borrador quedó persistido
SELECT 'BORRADOR_COMMIT' AS caso, count(*) AS borradores FROM pedido_borrador
 WHERE id_local='11111111-1111-4111-8111-111111111111';
SELECT 'ITEMS_COMMIT' AS caso, count(*) AS items FROM item_borrador
 WHERE id_local='11111111-1111-4111-8111-111111111111';
SELECT 'COLA_COMMIT' AS caso, estado FROM cola_sync
 WHERE solicitud_uuid='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';

-- (1b) Otra operación deshecha con ROLLBACK
BEGIN;
INSERT INTO pedido_borrador (id_local,usuario,forma_pago,fecha)
  VALUES ('22222222-2222-4222-8222-222222222222','vend_feria_1','TARJETA','2026-11-05T10:20:00Z');
INSERT INTO item_borrador (id_local,producto_id,cantidad,precio_centavos_visto)
  VALUES ('22222222-2222-4222-8222-222222222222', 5, 1, 493511);
ROLLBACK;

SELECT 'TRAS_ROLLBACK' AS caso, count(*) AS borradores_fantasma FROM pedido_borrador
 WHERE id_local='22222222-2222-4222-8222-222222222222';

-- C1: consulta del catálogo disponible sin conectarse al servidor (solo SQLite local)
SELECT 'C1_CATALOGO' AS caso, id, nombre, precio_centavos, stock_visto
FROM producto_cache
WHERE disponible = 1 AND eliminado = 0
ORDER BY id;

-- C7: cantidad 0 -> viola CHECK(cantidad > 0) => error, no deja filas nuevas
-- C7: producto inexistente -> viola FOREIGN KEY => error, no deja filas nuevas
-- (Estas sentencias fallan; ver ejecución/evidencia: la cuenta de ítems no cambia.)
-- INSERT INTO item_borrador (id_local,producto_id,cantidad,precio_centavos_visto)
--   VALUES ('11111111-1111-4111-8111-111111111111', 1, 0, 124984);           -- C7a: cantidad 0
-- INSERT INTO item_borrador (id_local,producto_id,cantidad,precio_centavos_visto)
--   VALUES ('11111111-1111-4111-8111-111111111111', 9999999, 1, 100);       -- C7b: producto inexistente

SELECT 'C7_ITEMS_ANTES_DESPUES' AS caso, count(*) AS items FROM item_borrador
 WHERE id_local='11111111-1111-4111-8111-111111111111';
