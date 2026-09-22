# spec: indice_producto_nombre_vig

Objetivo: acelerar la búsqueda de productos vigentes por nombre (búsqueda rápida en el sistema / catálogo).

Consulta afectada:
```sql
SELECT id, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND nombre LIKE 'Producto 1%';
```

Columnas candidatas: `nombre` (alta selectividad para prefijos, operador LIKE), `activo` (filtro de vigencia, baja selectividad).

Tipo propuesto: índice B-tree con `text_pattern_ops` (acelera `LIKE 'prefijo%'` con collation no-C) y **parcial** `WHERE activo` — solo se indexan los registros vigentes, reduciendo tamaño y costo de mantenimiento.

Criterio de aceptación: el plan pasa de `Seq Scan` a `Bitmap Index Scan`/`Index Scan` y el tiempo baja al menos un orden de magnitud.