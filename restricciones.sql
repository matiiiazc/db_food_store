-- ============================================================
-- FOOD STORE — restricciones.sql
-- TP1 - Parte 1: Integridad versionada
-- ============================================================
-- Reglas de negocio que hoy dependen de la aplicación y no
-- están garantizadas por el motor.
-- ============================================================


-- ============================================================
-- REGLA 1: Baja lógica — impedir DELETE directo
-- Solo se permite desactivar con UPDATE ... SET activo = FALSE,
-- nunca borrar físicamente un registro de categoria o producto.
-- ============================================================

-- Función que checkea si la operación es un DELETE
CREATE OR REPLACE FUNCTION fn_impedir_delete_logico()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'No está permitido eliminar registros físicamente. Use UPDATE ... SET activo = FALSE.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger sobre categoria
CREATE TRIGGER trg_categoria_no_delete
    BEFORE DELETE ON categoria
    FOR EACH ROW
    EXECUTE FUNCTION fn_impedir_delete_logico();

-- Trigger sobre producto
CREATE TRIGGER trg_producto_no_delete
    BEFORE DELETE ON producto
    FOR EACH ROW
    EXECUTE FUNCTION fn_impedir_delete_logico();


-- ============================================================
-- REGLA 2: Stock al crear detalle — decrementar stock y
-- verificar que no quede negativo
-- ============================================================

CREATE OR REPLACE FUNCTION fn_descontar_stock()
RETURNS TRIGGER AS $$
BEGIN
    -- Verificar que hay stock suficiente
    IF (SELECT stock FROM producto WHERE id = NEW.producto_id) < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para el producto id=%. Stock actual: %, cantidad pedida: %',
            NEW.producto_id,
            (SELECT stock FROM producto WHERE id = NEW.producto_id),
            NEW.cantidad;
    END IF;

    -- Descontar stock
    UPDATE producto
    SET stock = stock - NEW.cantidad
    WHERE id = NEW.producto_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger sobre detalle_pedido
CREATE TRIGGER trg_detalle_descontar_stock
    BEFORE INSERT ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_descontar_stock();


-- ============================================================
-- REGLA 3: Subtotal consistente — debe ser cantidad × precio_unitario
-- ============================================================

CREATE OR REPLACE FUNCTION fn_verificar_subtotal()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.subtotal != (NEW.cantidad * NEW.precio_unitario) THEN
        RAISE EXCEPTION 'El subtotal (%) no coincide con cantidad (%) × precio_unitario (%). Resultado esperado: %',
            NEW.subtotal,
            NEW.cantidad,
            NEW.precio_unitario,
            (NEW.cantidad * NEW.precio_unitario);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger sobre detalle_pedido
CREATE TRIGGER trg_detalle_verificar_subtotal
    BEFORE INSERT OR UPDATE ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_verificar_subtotal();
