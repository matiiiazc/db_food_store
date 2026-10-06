-- ============================================================================
-- TP6 - Unidad 4 | Parte 2 - Desnormalizacion controlada del panel
-- Food Store: top 5 de categorias por monto vendido en el dia
--
-- Requiere: copia poblada de Food Store con baja logica en pedido y
--           detalle_pedido (columna eliminado) y pedidos del dia a medir
--           (ver 00_setup_ambiente.sql del mismo TP).
--
-- Contenido:
--   a) Consulta original del reporte (version con EXPLAIN ANALYZE 1..LIMIT)
--      NOTA: el enunciado filtra `ped.fecha = CURRENT_DATE`. fecha es
--      TIMESTAMPTZ y CURRENT_DATE es DATE: esa igualdad solo matchea la
--      medianoche exacta (0 filas en la practica). Se corrige al rango
--      [CURRENT_DATE, CURRENT_DATE + 1) sin cambiar el plan ni la tematica.
--   c) Estructura desnormalizada: vista materializada mv_top_categorias_dia
--      + indice unico (habilita REFRESH CONCURRENTLY)
--   d) Consulta del reporte leyendo SOLO de la MV + EXPLAIN ANALYZE
--   e) Script de auditoria de desincronizacion (debe dar 0 filas)
--
-- Patron elegido: VISTA MATERIALIZADA (no columna precalculada por trigger).
-- Justificacion en el informe 03_informe_tp6.md (seccion Parte 2).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- (c) Estructura desnormalizada: total por (dia, categoria) precalculado.
--     La fuente de verdad son las 4 tablas; la MV es una proyeccion
--     materializada con el filtro de baja logica ya aplicado.
-- ----------------------------------------------------------------------------
DROP MATERIALIZED VIEW IF EXISTS mv_top_categorias_dia;

CREATE MATERIALIZED VIEW mv_top_categorias_dia AS
SELECT ped.fecha::date            AS dia,
       c.id                       AS categoria_id,
       c.nombre                   AS categoria,
       SUM(dp.subtotal)::NUMERIC(12,2) AS total_vendido
FROM detalle_pedido dp
JOIN pedido  ped ON ped.id = dp.pedido_id
JOIN producto pr  ON pr.id  = dp.producto_id
JOIN categoria c  ON c.id   = pr.categoria_id
WHERE dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY ped.fecha::date, c.id, c.nombre;

-- Indice unico sobre (dia, categoria_id): acelera la consulta del panel
-- Y es requisito de REFRESH MATERIALIZED VIEW CONCURRENTLY.
CREATE UNIQUE INDEX uq_mv_top_categorias_dia ON mv_top_categorias_dia (dia, categoria_id);

-- Mecanismo de sincronizacion: REFRESH CONCURRENTLY re-materializa el
-- agregado leyendo la fuente de verdad sin bloquear lecturas. El panel lo
-- programa (ej: cada 1-5 min) y lee la MV.
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_top_categorias_dia;

-- ----------------------------------------------------------------------------
-- (d) Consulta del reporte escrita contra la estructura desnormalizada.
--     Mismo reporte: top 5 por monto vendido del dia, directamente de la MV.
-- ----------------------------------------------------------------------------
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT categoria, total_vendido
FROM mv_top_categorias_dia
WHERE dia = CURRENT_DATE
ORDER BY total_vendido DESC
LIMIT 5;

-- ----------------------------------------------------------------------------
-- (e) Auditoria de desincronizacion.
--     Recalcula el agregado completo desde las 4 tablas (fuente de verdad)
--     y lo compara fila por fila contra la MV con FULL JOIN + IS DISTINCT FROM.
--     Debajo de OPEN EXPECTED 0 ROWS: si devuelve filas, la MV esta
--     desincronizada de su fuente.
-- ----------------------------------------------------------------------------
SELECT m.dia, m.categoria_id,
       m.total_vendido  AS mv_total,
       x.total_vendido  AS fuente_total,
       CASE
         WHEN m.dia IS NULL      THEN 'fila nueva en fuente, falta en MV'
         WHEN x.dia IS NULL      THEN 'fila en MV, ya no esta en la fuente'
         ELSE 'valor distinto'
       END AS tipo_desync
FROM mv_top_categorias_dia m
FULL JOIN (
    SELECT ped.fecha::date AS dia,
           c.id            AS categoria_id,
           SUM(dp.subtotal)::NUMERIC(12,2) AS total_vendido
    FROM detalle_pedido dp
    JOIN pedido  ped ON ped.id = dp.pedido_id
    JOIN producto pr  ON pr.id  = dp.producto_id
    JOIN categoria c  ON c.id   = pr.categoria_id
    WHERE dp.eliminado = FALSE
      AND ped.eliminado = FALSE
    GROUP BY ped.fecha::date, c.id, c.nombre
) x ON x.dia = m.dia AND x.categoria_id = m.categoria_id
WHERE m.total_vendido IS DISTINCT FROM x.total_vendido
   OR m.dia IS NULL OR x.dia IS NULL;