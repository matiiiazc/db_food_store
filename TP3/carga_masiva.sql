-- ============================================================
-- FOOD STORE - TP3 - Parte 1: carga masiva (seed voluminoso)
-- ============================================================
-- Objetivo: poblar la base para que los planes de ejecucion sean
-- lentos a escala real (Seq Scan) y la optimizacion sea medible.
--
-- Volumen objetivo (consigna del TP3):
--   * >= 50.000 productos  distribuidos entre categorias existentes
--   * 20.000 clientes
--   * 200.000 pedidos con sus detalles (detalle_pedido)
--
-- PROTOCOLO DE SEGURIDAD (catedra): copia, transaccion, respaldo.
--   Este script corre sobre food_store_tp3 (copia de trabajo),
--   NUNCA sobre plantilla_base. Previamente se tomo un pg_dump.
--
-- DECISION JUSTIFICADA sobre los triggers de la Parte 1 del TP2:
--   Las 3 restricciones (baja logica, stock, subtotal) estan
--   pensadas para operacion transaccional de a-uno. Durante un
--   bulk insert masivo el trigger de stock haria centenares de
--   miles de SELECT + UPDATE de una fila (lentisimo) y dejaria
--   los stocks en negativo. Lo profesional es DESACTIVAR los
--   triggers durante la carga y REACTIVARLOS al final, porque:
--     1) la carga es un seed, no una venta real (no debe disparar
--        la logica de negocio del TP2);
--     2) se restaura el estado exacto antes/despues.
--   Se documenta en la DUIA como decision aceptada y reversible.
--   (No se desactiva trg_*_no_delete porque no se hace DELETE.)
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- Paso 0: desactivar triggers de negocio durante el seed
-- ------------------------------------------------------------
ALTER TABLE detalle_pedido DISABLE TRIGGER ALL;
ALTER TABLE producto        DISABLE TRIGGER ALL;
ALTER TABLE categoria       DISABLE TRIGGER ALL;

-- ------------------------------------------------------------
-- Paso 1: categorias base (si no existen)
-- ------------------------------------------------------------
INSERT INTO categoria (nombre) VALUES
    ('Pizzas'),
    ('Empanadas'),
    ('Bebidas'),
    ('Postres')
ON CONFLICT (nombre) DO NOTHING;

-- ------------------------------------------------------------
-- Paso 2: 50.000 productos distribuidos entre categorias
--   Precio entre 500 y 5000, stock aleatorio 0..200.
--   generate_series de 1..50000; se reparten 4 categorias.
-- ------------------------------------------------------------
INSERT INTO producto (nombre, descripcion, precio, stock, activo, categoria_id)
SELECT
    'Producto ' || g,                                  -- nombre unico
    'Descripcion generada para el producto ' || g,
    round((500 + random() * 4500)::numeric, 2),        -- precio 500..5000
    floor(random() * 201)::int,                        -- stock 0..200
    TRUE,
    (SELECT id FROM categoria WHERE nombre = (ARRAY['Pizzas','Empanadas','Bebidas','Postres'])[1 + (g % 4)]) -- reparto parejo
FROM generate_series(1, 50000) AS g;

-- ------------------------------------------------------------
-- Paso 3: 20.000 clientes
-- ------------------------------------------------------------
INSERT INTO cliente (nombre, apellido, email, telefono)
SELECT
    'Nombre' || g,
    'Apellido' || g,
    'cliente' || g || '@foodstore.com',
    '11' || lpad(g::text, 8, '0')
FROM generate_series(1, 20000) AS g;

-- ------------------------------------------------------------
-- Paso 4: 200.000 pedidos con detalles
--   Cada pedido tiene 1..4 lineas de detalle con cantidad 1..9.
--   El trigger de subtotal esta desactivado, pero igual cargamos
--   subtotal = cantidad * precio_unitario (consistente).
-- ------------------------------------------------------------
WITH pedidos AS (
    SELECT
        g AS n,
        now() - (random() * interval '400 days') AS fecha,
        (ARRAY['EFECTIVO','TARJETA','TRANSFERENCIA'])[1 + floor(random()*3)::int]::forma_pago_enum AS fp,
        1 + floor(random() * 20000)::int AS cliente_id
    FROM generate_series(1, 200000) AS g
)
INSERT INTO pedido (fecha, forma_pago, cliente_id)
SELECT fecha, fp, cliente_id FROM pedidos;

-- Detalles: para cada pedido, 2..4 lineas de detalle (cada una con
-- un producto distinto dentro del mismo pedido, respetando
-- uq_detalle_pedido_producto). cantidad 1..9, subtotal consistente.
-- Se usa generate_series para las lineas y se asigna un producto
-- diferente a cada linea del mismo pedido (desplazamiento por linea)
-- para evitar colisiones de unicidad dentro de un pedido.
-- Volumen: 200.000 pedidos x 3 lineas en promedio = ~600.000 detalles.
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
SELECT
    p.id,
    1 + ((p.id * 7 + linea) % 50000)::int AS producto_id,  -- producto distinto por linea
    1 + floor(random() * 9)::int           AS cantidad,
    pr.precio,
    pr.precio * (1 + floor(random() * 9)::int) AS subtotal
FROM generate_series(1, 200000) AS g
JOIN LATERAL (SELECT id FROM pedido WHERE id = g) p ON true
CROSS JOIN generate_series(0, 2) AS linea            -- 3 lineas por pedido
CROSS JOIN LATERAL (
    SELECT precio FROM producto WHERE id = 1 + ((g * 7 + linea) % 50000)::int
) pr;

-- ------------------------------------------------------------
-- Paso 5: ANALYZE para refrescar estadisticas del optimizador
-- ------------------------------------------------------------
ANALYZE categoria;
ANALYZE producto;
ANALYZE cliente;
ANALYZE pedido;
ANALYZE detalle_pedido;

-- ------------------------------------------------------------
-- Paso 6: reactivar triggers de negocio (estado original)
-- ------------------------------------------------------------
ALTER TABLE detalle_pedido ENABLE TRIGGER ALL;
ALTER TABLE producto        ENABLE TRIGGER ALL;
ALTER TABLE categoria       ENABLE TRIGGER ALL;

COMMIT;

-- ------------------------------------------------------------
-- Verificacion de conteos (despues del COMMIT)
-- ------------------------------------------------------------
SELECT 'categoria' AS tabla, count(*) FROM categoria
UNION ALL SELECT 'producto', count(*) FROM producto
UNION ALL SELECT 'cliente',  count(*) FROM cliente
UNION ALL SELECT 'pedido',   count(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', count(*) FROM detalle_pedido;
