# spec: vista materializada facturacion por categoria y mes

Objetivo: reporte agregado costoso — facturación por categoría y mes — para que se responda en milisegundos sin re-agregar 600.000 detalles.

Reporte base (Semana 4, Consulta 1):
```sql
SELECT to_char(date_trunc('month', p.fecha), 'YYYY-MM') AS mes,
       c.nombre AS categoria,
       sum(dp.subtotal) AS facturado
FROM detalle_pedido dp
JOIN pedido   p  ON p.id  = dp.pedido_id
JOIN producto pr ON pr.id = dp.producto_id
JOIN categoria c ON c.id  = pr.categoria_id
GROUP BY mes, c.nombre
ORDER BY mes, facturado DESC;
```
Tiempo medido en la Semana 4: ~2050 ms (optimizada) / 4387 ms (original). Reporte solicitado por negocio con periodicidad mensual.

Vista materializada: `mv_facturacion_categoria_mes`, creada con `WITH DATA`.

Índice único requerido: `(mes, categoria)` — además de acelerar, habilita un futuro `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

Criterio de aceptación:
1. La consulta contra la MV devuelve el mismo resultado que el reporte base (equivalencia por comparación de resultados).
2. El tiempo de consulta de la MV debe ser órdenes de magnitud menor que el reporte base sin materializar.