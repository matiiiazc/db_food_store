-- TP Unidad 7 - Food Store - Consultas equivalentes en PostgreSQL (Parte 2)
-- Base: food_store_tp3. Subconjunto migrado: pedidos 1-5.

-- Contexto: los 5 pedidos migrados (id + estado derivado de eliminado)
SELECT p.id, CASE WHEN p.eliminado THEN 'ANULADO' ELSE 'ACTIVO' END AS estado
FROM pedido p
WHERE p.id IN (1,2,3,4,5)
ORDER BY p.id;

-- (b) Equivalente: pedidos por estado ACTIVO (eliminado = false)
--    dentro del subconjunto migrado, para comparación verificable con MongoDB.
SELECT p.id, CASE WHEN p.eliminado THEN 'ANULADO' ELSE 'ACTIVO' END AS estado
FROM pedido p
WHERE p.id IN (1,2,3,4,5)
  AND (p.eliminado = false OR p.eliminado IS NULL)
ORDER BY p.id;

-- Conteo e IDs (b)
SELECT COUNT(*) AS cantidad,
       array_agg(p.id ORDER BY p.id) AS ids
FROM pedido p
WHERE p.id IN (1,2,3,4,5)
  AND (p.eliminado = false OR p.eliminado IS NULL);

-- (c) Equivalente: pedidos que contienen el producto 'Producto 16'
SELECT DISTINCT p.id
FROM pedido p
JOIN detalle_pedido d ON d.pedido_id = p.id AND (d.eliminado = false OR d.eliminado IS NULL)
JOIN producto pr ON pr.id = d.producto_id
WHERE p.id IN (1,2,3,4,5)
  AND pr.nombre = 'Producto 16'
ORDER BY p.id;

-- Conteo e IDs (c)
SELECT COUNT(DISTINCT p.id) AS cantidad,
       array_agg(DISTINCT p.id ORDER BY p.id) AS ids
FROM pedido p
JOIN detalle_pedido d ON d.pedido_id = p.id AND (d.eliminado = false OR d.eliminado IS NULL)
JOIN producto pr ON pr.id = d.producto_id
WHERE p.id IN (1,2,3,4,5)
  AND pr.nombre = 'Producto 16';

-- Referencia (d): totales para justificar/verificar umbral 30000
SELECT p.id,
       COALESCE(SUM(d.subtotal),0) AS total
FROM pedido p
LEFT JOIN detalle_pedido d ON d.pedido_id = p.id AND (d.eliminado = false OR d.eliminado IS NULL)
WHERE p.id IN (1,2,3,4,5)
GROUP BY p.id
ORDER BY p.id;
