BEGIN;

-- SETUP
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

-- TEST 1: DELETE directo (debe FALLAR)
DELETE FROM categoria WHERE nombre = 'Pizzas';

-- TEST 2: UPDATE logico (debe funcionar)
UPDATE categoria SET activo = FALSE WHERE nombre = 'Bebidas';

-- TEST 3: INSERT detalle stock suficiente (debe funcionar)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Muzzarella'),
    3, 800.00, 2400.00
);

SELECT nombre, stock FROM producto WHERE nombre = 'Muzzarella';

-- TEST 4: INSERT detalle stock insuficiente (debe FALLAR)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Coca-Cola'),
    100, 500.00, 50000.00
);

-- TEST 5: subtotal incorrecto (debe FALLAR)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Coca-Cola'),
    2, 500.00, 9999.00
);

-- TEST 6: subtotal correcto (debe funcionar)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Coca-Cola'),
    2, 500.00, 1000.00
);

-- RESUMEN
SELECT nombre, activo FROM categoria;
SELECT nombre, stock, activo FROM producto;

ROLLBACK;
