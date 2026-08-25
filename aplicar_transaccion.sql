BEGIN;

-- REGLA 1: Baja logica
CREATE OR REPLACE FUNCTION fn_impedir_delete_logico()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'No esta permitido eliminar registros fisicamente. Use UPDATE ... SET activo = FALSE.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_categoria_no_delete
    BEFORE DELETE ON categoria
    FOR EACH ROW
    EXECUTE FUNCTION fn_impedir_delete_logico();

CREATE TRIGGER trg_producto_no_delete
    BEFORE DELETE ON producto
    FOR EACH ROW
    EXECUTE FUNCTION fn_impedir_delete_logico();

-- REGLA 2: Stock
CREATE OR REPLACE FUNCTION fn_descontar_stock()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT stock FROM producto WHERE id = NEW.producto_id) < NEW.cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente para el producto id=%. Stock actual: %, cantidad pedida: %',
            NEW.producto_id,
            (SELECT stock FROM producto WHERE id = NEW.producto_id),
            NEW.cantidad;
    END IF;

    UPDATE producto
    SET stock = stock - NEW.cantidad
    WHERE id = NEW.producto_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_detalle_descontar_stock
    BEFORE INSERT ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_descontar_stock();

-- REGLA 3: Subtotal consistente
CREATE OR REPLACE FUNCTION fn_verificar_subtotal()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.subtotal != (NEW.cantidad * NEW.precio_unitario) THEN
        RAISE EXCEPTION 'El subtotal (%) no coincide con cantidad (%) x precio_unitario (%). Resultado esperado: %',
            NEW.subtotal,
            NEW.cantidad,
            NEW.precio_unitario,
            (NEW.cantidad * NEW.precio_unitario);
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_detalle_verificar_subtotal
    BEFORE INSERT OR UPDATE ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_verificar_subtotal();

-- Verificar triggers creados
SELECT trigger_name, event_manipulation, event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- Verificar funciones creadas
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
  AND routine_name LIKE 'fn_%'
ORDER BY routine_name;

COMMIT;
