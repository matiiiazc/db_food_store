# spec: indice_pedido_fecha_forma_pago

Objetivo: acelerar el reporte de pedidos por forma de pago en un rango de fechas (reporte de caja / conciliación mensual).

Consulta afectada:
```sql
SELECT id, fecha, cliente_id, forma_pago
FROM pedido
WHERE forma_pago = 'TARJETA'
  AND fecha >= '2026-01-01'
  AND fecha <  '2026-02-01';
```

Columnas candidatas: `forma_pago` (muy baja selectividad: solo 3 valores) y `fecha` (alta selectividad). Por cómo se consulta (filtro de = con el segundo columnas en rango), el índice compuesto `(forma_pago, fecha)` permite un acceso directo por el criterio de igualdad y recorrer solo el rango de fechas.

Tipo propuesto: índice B-tree compuesto `(forma_pago, fecha)` — igualdad primero, rango después.

Criterio de aceptación: el plan actual usa `Bitmap Index Scan on idx_pedido_fecha` con `Filter: forma_pago` (rechecks 10375); se espera pasar a `Index Scan` sobre el nuevo índice eliminando el recheck, con reducción medible de tiempo.