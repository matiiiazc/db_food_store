-- ============================================================
-- FOOD STORE - test_restricciones.sql
-- Prueba las restricciones dentro de una transaccion
-- Usa SAVEPOINT para que un error no aborte el resto de los tests
-- ============================================================
-- Ejecutar desde la terminal:
--   psql -d copia_trabajo -f test_restricciones.sql
-- Resultado: los 3 primeros errores son ESPERADOS (reglas que
-- rechazan datos invalidos). Al final va ROLLBACK.
-- ============================================================

BEGIN;

-- ============================================================
-- SETUP: datos de prueba
-- ============================================================

INSERT INTO categoria (nombre) VALUES ('Pizzas');
INSERT INTO categoria (nombre) VALUES ('Bebidas');

INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Muzzarella', 800.00, 10, TRUE,
        (SELECT id FROM categoria WHERE nombre = 'Pizzas'));

INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Coca-Cola', 500.00, 20, TRUE,
        (SELECT id FROM categoria WHERE nombre = 'Bebidas'));

INSERT INTO cliente (nombre, apellido, email)
VALUES ('Juan', 'Perez', 'juan@test.com');

INSERT INTO pedido (forma_pago, cliente_id)
VALUES ('EFECTIVO',
        (SELECT id FROM cliente WHERE email = 'juan@test.com'));

-- ============================================================
-- TEST 1: Baja logica - DELETE directo (debe FALLAR)
-- ============================================================

SAVEPOINT test1;
DELETE FROM categoria WHERE nombre = 'Pizzas';
-- ERROR esperado: "No esta permitido eliminar registros fisicamente..."
ROLLBACK TO test1;

-- ============================================================
-- TEST 2: Baja logica - UPDATE logico (debe funcionar)
-- ============================================================

UPDATE categoria SET activo = FALSE WHERE nombre = 'Bebidas';
-- OK, 1 fila afectada

-- ============================================================
-- TEST 3: Stock - INSERT valido (debe funcionar y bajar stock)
-- ============================================================

INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Muzzarella'),
    3, 800.00, 2400.00
);
-- OK

SELECT nombre, stock FROM producto WHERE nombre = 'Muzzarella';
-- Stock esperado: 7

-- ============================================================
-- TEST 4: Stock - INSERT con stock insuficiente (debe FALLAR)
-- ============================================================

SAVEPOINT test4;
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Coca-Cola'),
    100, 500.00, 50000.00
);
-- ERROR esperado: "Stock insuficiente..."
ROLLBACK TO test4;

-- ============================================================
-- TEST 5: Subtotal - subtotal incorrecto (debe FALLAR)
-- ============================================================

SAVEPOINT test5;
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Coca-Cola'),
    2, 500.00, 9999.00
);
-- ERROR esperado: "El subtotal no coincide..."
ROLLBACK TO test5;

-- ============================================================
-- TEST 6: Subtotal - subtotal correcto (debe funcionar)
-- ============================================================

INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Coca-Cola'),
    2, 500.00, 1000.00
);
-- OK

-- ============================================================
-- RESUMEN
-- ============================================================

SELECT nombre, activo FROM categoria;
SELECT nombre, stock, activo FROM producto;

ROLLBACK;