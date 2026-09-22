# spec: indice_cliente_apellido

Objetivo: acelerar la búsqueda de clientes por apellido (búsqueda frecuente al atender un pedido o resolver un reclamo).

Consulta afectada:
```sql
SELECT id, nombre, apellido, email
FROM cliente
WHERE apellido = 'Apellido470';
```

Columnas candidatas: `apellido` (alta selectividad; hoy la tabla se recorre completa con Seq Scan).

Tipo propuesto: índice B-tree simple sobre `apellido`.

Criterio de aceptación: el plan pasa de `Seq Scan` a `Index Scan` y el tiempo baja al menos un orden de magnitud.