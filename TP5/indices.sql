-- ============================================================
-- TP5 - Parte A - Plan de indexado asistido por IA
-- indices.sql
-- Esquema: Food Store (schema.sql de la Semana 1, sin modificar)
-- Base: food_store_tp3 (masiva)
-- ============================================================
-- Criterio de la cátedra: cada índice se justifica con un spec
-- (carpeta specs/) y con EXPLAIN ANALYZE antes/después medido en
-- informe_mediciones.md. El índice descartado por sobreindexación
-- está documentado en specs/spec_indice_descartado_producto_categoria.md
-- y NO se crea aquí.
-- ============================================================

-- 1) Búsqueda de productos vigentes por nombre (spec_indice_producto_nombre_vig).
--    B-tree con text_pattern_ops para acelerar LIKE 'prefijo%' con collation no-C,
--    y parcial WHERE activo para indexar solo el catálogo vigente.
CREATE INDEX idx_producto_nombre_vig
    ON producto (nombre text_pattern_ops)
    WHERE activo;

-- 2) Búsqueda de clientes por apellido (spec_indice_cliente_apellido).
--    B-tree simple: hoy la tabla se recorre completa (Seq Scan).
CREATE INDEX idx_cliente_apellido
    ON cliente (apellido);

-- 3) Reporte de pedidos por forma de pago en un rango de fechas
--    (spec_indice_pedido_fecha_forma_pago).
--    Compuesto (forma_pago, fecha): igualdad sobre la columna de baja
--    cardinalidad primero y rango sobre la de alta selectividad después,
--    para recorrer índice sin rechecks sobre el heap.
CREATE INDEX idx_pedido_forma_fecha
    ON pedido (forma_pago, fecha);