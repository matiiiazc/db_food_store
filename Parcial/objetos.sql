-- ============================================================
-- TPI Food Store - Objetivo 6: objetos programables PL/pgSQL
-- Vistas, funciones y PROCEDIMIENTO almacenado invocado con CALL.
-- Requiere: schema.sql (ddl.sql) cargado + base food_store_tp3.
-- ============================================================

-- ------------------------------------------------------------
-- A) VISTAS (3)
-- ------------------------------------------------------------

-- 1. Catalogo vigente con nombre de categoria
CREATE OR REPLACE VIEW vista_productos_vigentes AS
SELECT pr.id, pr.nombre, pr.precio, pr.stock, c.nombre AS categoria
FROM producto pr
JOIN categoria c ON c.id = pr.categoria_id
WHERE pr.activo = TRUE AND c.activo = TRUE;

-- 2. Pedidos con datos del cliente (sin telefono: no exponer dato sensible)
CREATE OR REPLACE VIEW vista_pedidos_cliente AS
SELECT p.id AS pedido_id, p.fecha, p.forma_pago,
       c.nombre, c.apellido, c.email
FROM pedido p
JOIN cliente c ON c.id = p.cliente_id;

-- 3. Detalle con nombre de producto (historial facturado)
CREATE OR REPLACE VIEW vista_detalle_pedido AS
SELECT dp.pedido_id, pr.nombre AS producto, dp.cantidad,
       dp.precio_unitario, dp.subtotal
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id;

-- ------------------------------------------------------------
-- B) FUNCIONES (3) — incluye las de integridad del TP2
-- ------------------------------------------------------------

-- 1. Funcion de trigger: impedir DELETE fisico (soft delete, R7)
CREATE OR REPLACE FUNCTION fn_impedir_delete_logico()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'No esta permitido eliminar registros fisicamente. Use UPDATE ... SET activo = FALSE.';
END;
$$ LANGUAGE plpgsql;

-- 2. Funcion de trigger: descontar stock y validar disponibilidad
CREATE OR REPLACE FUNCTION fn_descontar_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT stock FROM producto WHERE id = NEW.producto_id) < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para el producto id=%',
            NEW.producto_id;
    END IF;
    UPDATE producto SET stock = stock - NEW.cantidad
    WHERE id = NEW.producto_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Funcion escalar: total facturado por un cliente
CREATE OR REPLACE FUNCTION fn_total_cliente(p_cliente_id BIGINT)
RETURNS NUMERIC(14,2) AS $$
DECLARE
    v_total NUMERIC(14,2);
BEGIN
    SELECT COALESCE(sum(dp.subtotal), 0) INTO v_total
    FROM pedido p
    JOIN detalle_pedido dp ON dp.pedido_id = p.id
    WHERE p.cliente_id = p_cliente_id;
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------
-- C) PROCEDIMIENTO almacenado invocado con CALL (PL/pgSQL)
--    Requisito especifico del motor (PostgreSQL 16+): separa la
--    transaccion en el caller, se invoca con CALL.
-- ------------------------------------------------------------

CREATE OR REPLACE PROCEDURE sp_registrar_pedido(
    p_cliente_id   BIGINT,
    p_forma_pago   forma_pago_enum,
    p_productos    BIGINT[],   -- ids de producto
    p_cantidades   INTEGER[]   -- cantidades por producto
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_pedido_id BIGINT;
    v_idx       INTEGER;
BEGIN
    -- El CALLER debe estar dentro de una transaccion (BEGIN...COMMIT)
    -- para que atomicidad + triggers + desencadenado queden unificados.
    IF array_length(p_productos, 1) IS DISTINCT FROM array_length(p_cantidades, 1) THEN
        RAISE EXCEPTION 'Los arreglos de producto y cantidad no coinciden';
    END IF;

    INSERT INTO pedido (fecha, forma_pago, cliente_id)
    VALUES (now(), p_forma_pago, p_cliente_id)
    RETURNING id INTO v_pedido_id;

    FOR v_idx IN 1..array_length(p_productos, 1) LOOP
        INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
        VALUES (v_pedido_id,
                p_productos[v_idx],
                p_cantidades[v_idx],
                (SELECT precio FROM producto WHERE id = p_productos[v_idx]),
                (SELECT precio FROM producto WHERE id = p_productos[v_idx]) * p_cantidades[v_idx]);
        -- El trigger fn_descontar_stock valida stock y descuenta.
    END LOOP;

    RAISE NOTICE 'Pedido % registrado para el cliente %', v_pedido_id, p_cliente_id;
END;
$$;