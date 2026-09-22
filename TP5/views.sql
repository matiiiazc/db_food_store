-- ============================================================
-- TP5 - Parte B y C - Vistas y vista materializada
-- views.sql
-- ============================================================
-- Parte B: tres vistas para reportes, especificadas en specs/.
-- Cada vista se verifico contra su consulta manual equivalente
-- (resultados identicos, comparados con EXCEPT / conteo).
-- Parte C: vista materializada de facturacion por categoria y mes
-- con indice unico para futuro REFRESH CONCURRENTLY.
-- ============================================================

-- ------------------------------------------------------------
-- Parte B
-- ------------------------------------------------------------

-- 1) Catalogo vigente con nombre de categoria (spec_vista_productos_vigentes).
--    Seguridad: expone solo columnas de negocio; permite SELECT sin acceso
--    a las tablas base (no se exponen descripcion/activo/created_at).
CREATE VIEW vista_productos_vigentes AS
SELECT pr.id,
       pr.nombre,
       pr.precio,
       pr.stock,
       c.nombre AS categoria
FROM producto pr
JOIN categoria c ON c.id = pr.categoria_id
WHERE pr.activo = TRUE
  AND c.activo  = TRUE;

-- 2) Pedidos con datos del cliente (spec_vista_pedidos_cliente).
--    Seguridad: no expone cliente.telefono (dato sensible) en la vista.
CREATE VIEW vista_pedidos_cliente AS
SELECT p.id       AS pedido_id,
       p.fecha,
       p.forma_pago,
       c.nombre,
       c.apellido,
       c.email
FROM pedido p
JOIN cliente c ON c.id = p.cliente_id;

-- 3) Detalle de un pedido con nombre del producto (spec_vista_detalle_pedido).
--    No filtra por producto.activo: el histórico facturado debe verse aunque
--    el producto se haya desactivado despues (integridad del ticket).
CREATE VIEW vista_detalle_pedido AS
SELECT dp.pedido_id,
       pr.nombre AS producto,
       dp.cantidad,
       dp.precio_unitario,
       dp.subtotal
FROM detalle_pedido dp
JOIN producto pr ON pr.id = dp.producto_id;

-- ------------------------------------------------------------
-- Parte C
-- ------------------------------------------------------------

-- 4) Reporte agregado costoso: facturacion por categoria y mes
--    (spec_vista_materializada_facturacion). Con WITH DATA.
CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT to_char(date_trunc('month', p.fecha), 'YYYY-MM') AS mes,
       c.nombre                                          AS categoria,
       sum(dp.subtotal)                                  AS facturado
FROM detalle_pedido dp
JOIN pedido     p  ON p.id  = dp.pedido_id
JOIN producto   pr ON pr.id = dp.producto_id
JOIN categoria  c  ON c.id  = pr.categoria_id
GROUP BY mes, c.nombre
WITH DATA;

-- Indice unico que habilita un futuro REFRESH CONCURRENTLY.
CREATE UNIQUE INDEX uq_mv_facturacion_mes_categoria
    ON mv_facturacion_categoria_mes (mes, categoria);