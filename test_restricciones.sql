-- ============================================================
-- FOOD STORE — test_restricciones.sql
-- Prueba las restricciones dentro de una transacción
-- ============================================================
-- Ejecutar desde la terminal:
--   psql -d copia_trabajo -f test_restricciones.sql
-- ============================================================


BEGIN;

-- ============================================================
-- SETUP: datos de prueba
-- ============================================================

-- Categoría
INSERT INTO categoria (nombre) VALUES ('Pizzas');
INSERT INTO categoria (nombre) VALUES ('Bebidas');

-- Productos
INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Muzzarella', 800.00, 10, TRUE,
        (SELECT id FROM categoria WHERE nombre = 'Pizzas'));

INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Coca-Cola', 500.00, 20, TRUE,
        (SELECT id FROM categoria WHERE nombre = 'Bebidas'));

-- Cliente
INSERT INTO cliente (nombre, apellido, email)
VALUES ('Juan', 'Pérez', 'juan@test.com');

-- Pedido
INSERT INTO pedido (forma_pago, cliente_id)
VALUES ('EFECTIVO',
        (SELECT id FROM cliente WHERE email = 'juan@test.com'));


-- ============================================================
-- TEST 1: Baja lógica — DELETE directo (debe FALLAR)
-- ============================================================

\echo '--- TEST 1: DELETE directo en categoria (debe fallar) ---'
DELETE FROM categoria WHERE nombre = 'Pizzas';
-- Esperado: ERROR "No está permitido eliminar registros físicamente..."


-- ============================================================
-- TEST 2: Baja lógica — UPDATE lógico (debe funcionar)
-- ============================================================

\echo '--- TEST 2: UPDATE logico en categoria (debe funcionar) ---'
UPDATE categoria SET activo = FALSE WHERE nombre = 'Bebidas';
-- Esperado: OK, 1 fila afectada


-- ============================================================
-- TEST 3: Stock — INSERT válido (debe funcionar)
-- ============================================================

\echo '--- TEST 3: INSERT detalle con stock suficiente (debe funcionar) ---'
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Muzzarella'),
    3, 800.00, 2400.00
);
-- Esperado: OK

-- Verificar stock decrementado
\echo 'Stock después del INSERT:'
SELECT nombre, stock FROM producto WHERE nombre = 'Muzzarella';
-- Esperado: stock = 7


-- ============================================================
-- TEST 4: Stock — INSERT con stock insuficiente (debe FALLAR)
-- ============================================================

\echo '--- TEST 4: INSERT detalle con stock insuficiente (debe fallar) ---'
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Coca-Cola'),
    100, 500.00, 50000.00
);
-- Esperado: ERROR "Stock insuficiente..."


-- ============================================================
-- TEST 5: Subtotal — subtotal incorrecto (debe FALLAR)
-- ============================================================

\echo '--- TEST 5: INSERT detalle con subtotal incorrecto (debe fallar) ---'
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Coca-Cola'),
    2, 500.00, 9999.00  -- 2 × 500 = 1000, no 9999
);
-- Esperado: ERROR "El subtotal no coincide..."


-- ============================================================
-- TEST 6: Subtotal — subtotal correcto (debe funcionar)
-- ============================================================

\echo '--- TEST 6: INSERT detalle con subtotal correcto (debe funcionar) ---'
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Coca-Cola'),
    2, 500.00, 1000.00
);
-- Esperado: OK


-- ============================================================
-- RESULTADO FINAL
-- ============================================================

\echo '--- Resumen de datos ---'
SELECT 'Categorias' as tabla, COUNT(*) as total FROM categoria
UNION ALL
SELECT 'Productos', COUNT(*) FROM producto
UNION ALL
SELECT 'Clientes', COUNT(*) FROM cliente
UNION ALL
SELECT 'Pedidos', COUNT(*) FROM pedido
UNION ALL
SELECT 'Detalles', COUNT(*) FROM detalle_pedido;

\echo '--- Estado de categorías ---'
SELECT nombre, activo FROM categoria;

\echo '--- Stock de productos ---'
SELECT nombre, stock, activo FROM producto;

-- Todo parece correcto
\echo 'Listo. Revisá los resultados y decidí: COMMIT o ROLLBACK.'

-- Si todo está bien, descomentá la siguiente línea:
-- COMMIT;

-- Si algo falló, descomentá la siguiente línea:
-- ROLLBACK;
