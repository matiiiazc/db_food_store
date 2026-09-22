# TP5 — Informe de mediciones (Parte A: plan de indexado)

Base: `food_store_tp3` masiva (50.000 productos, 20.000 clientes, 200.000 pedidos, 600.000 detalles de pedido).
Motor: PostgreSQL 18. Mediciones con `EXPLAIN ANALYZE` reales, antes/después.

## 1. Índices aplicados y consultas medidas

### Índice 1 — `idx_producto_nombre_vig` (B-tree parcial, spec: `spec_indice_producto_nombre_vig`)

```sql
CREATE INDEX idx_producto_nombre_vig
    ON producto (nombre text_pattern_ops)
    WHERE activo;
```

Consulta: búsqueda de productos vigentes por prefijo de nombre.

| Métrica | ANTES | DESPUÉS |
|---|---|---|
| Nodo | `Seq Scan on producto` (50.000 filas recorridas) | `Bitmap Index Scan on idx_producto_nombre_vig` + `Bitmap Heap Scan` |
| Filas removidas por filtro | 38.889 | 0 (el índice preselecciona por prefijo y vigencia) |
| Tiempo | **20.028 ms** | **14.369 ms** |

Nota: la mejora de tiempo es moderada porque el prefijo `'Producto 1%'` igualmente devuelve 11.111 filas, pero el cambio de plan es el esperado: de Seq Scan a Bitmap Index Scan sobre el índice parcial.

### Índice 2 — `idx_cliente_apellido` (B-tree simple, spec: `spec_indice_cliente_apellido`)

```sql
CREATE INDEX idx_cliente_apellido
    ON cliente (apellido);
```

Consulta: búsqueda de cliente por apellido.

| Métrica | ANTES | DESPUÉS |
|---|---|---|
| Nodo | `Seq Scan on cliente` (20.000 filas) | `Index Scan using idx_cliente_apellido` |
| Filas | 1 | 1 |
| Tiempo | **6.755 ms** | **0.214 ms** |

Mejora: **~31,5×**, caso típico donde un B-tree convierte un barrido completo en un acceso de índice.

### Índice 3 — `idx_pedido_forma_fecha` (B-tree compuesto, spec: `spec_indice_pedido_fecha_forma_pago`)

```sql
CREATE INDEX idx_pedido_forma_fecha
    ON pedido (forma_pago, fecha);
```

Consulta: pedidos de tarjeta de un mes (conciliación de caja).

| Métrica | ANTES | DESPUÉS |
|---|---|---|
| Nodo | `Bitmap Heap Scan on pedido` usando `idx_pedido_fecha` con `Filter: forma_pago = 'TARJETA'` (10.375 rechecks) | `Bitmap Index Scan on idx_pedido_forma_fecha` (index cond plena, **0 rechecks**) |
| Tiempo | **26.771 ms** | **20.506 ms** |

El índice compuesto `(forma_pago, fecha)` elimina los rechecks del heap al meter la igualdad de `forma_pago` en el Index Cond.

**Caso complementario (baja cardinalidad):** la consulta original candidata era `WHERE forma_pago = 'TARJETA'` sola (Seq Scan, 76 ms). Con el índice creado pasa a Bitmap Index Scan, pero **el tiempo empeora** (113 ms) porque debe tocar las mismas ~66.600 filas vía índice. Ningún índice puede acelerar un equality que devuelve el 33% de la tabla: ese filtro es aceptable como Seq Scan y la ganancia real está en combinar `forma_pago` con el rango de `fecha`. Esto apoya el criterio de solo crear índices para accesos selectivos.

## 2. Costo de escritura (carga de 300 INSERT en `pedido`)

Protocolo: batch de `INSERT ... SELECT generate_series` dentro de transacción con `ROLLBACK` (el costo del mantenimiento de índices se paga igual; no se contaminan datos).

| Estado | Tiempo (300 INSERT en pedido) |
|---|---|
| Sin los índices nuevos (solo índices de las semanas 1-4) | **47.516 ms** |
| Con los 3 índices nuevos de esta semana | **151.642 ms** |

Balance lectura/escritura: los 3 índices cuestan ~**+3,2×** en escrituras puntuales sobre las tablas que los contienen. Es el costo de mantenimiento esperado y se asume como aceptable porque:
- la carga masiva (que es la escritura realmente intensiva) se hace en lotes con los índices ya existentes en la práctica de la Semana 3;
- las consultas de lectura optimizadas son de las más frecuentes del sistema (catálogo, atención al cliente, conciliación de caja).

## 3. Verificación de equivalencia de las vistas (Parte B)

Cada vista se verificó contra su consulta manual equivalente comparando conteo de filas y `EXCEPT` (0 filas de diferencia).

| Vista | Filas (vista) | Filas (manual) | Diferencia (EXCEPT) |
|---|---|---|---|
| `vista_productos_vigentes` (catálogo vigente + categoría) | 50.000 | 50.000 | **0** |
| `vista_pedidos_cliente` (pedidos + cliente) | 200.000 | 200.000 | **0** |
| `vista_detalle_pedido` (líneas + nombre de producto) | 600.000 | 600.000 | **0** |

Nota de seguridad: `vista_pedidos_cliente` no expone `cliente.telefono`; `vista_productos_vigentes` no expone `descripcion`/`activo`/`created_at`. Ambas permiten otorgar `SELECT` sin acceso a las tablas base.

## 4. Vista materializada (Parte C)

Vista: `mv_facturacion_categoria_mes` (spec: `spec_vista_materializada_facturacion`), creada con `WITH DATA` e índice único `(mes, categoria)` que habilita `REFRESH CONCURRENTLY`.

| Métrica | Consulta base (4 tablas, sin materializar) | Vista materializada |
|---|---|---|
| Tiempo | **2824.277 ms** | **14.590 ms** |

Mejora: ~**193×**. La consulta original re-agrega 600.000 detalles (plan Hash Join + GroupAggregate); contra la MV es un scan plano de 60 filas con índice único.

**Verificación de equivalencia:** los resultados de la MV contra el reporte base son idénticos (mismas 60 filas, mismos totales por mes/categoría).

### Frecuencia de REFRESH y vigencia del dato

- **Frecuencia recomendada:** mensual, después del cierre contable de cada mes (el reporte "facturación por categoría y mes" se consume en esa cadencia). Con los 13 meses actuales, el `REFRESH MATERIALIZED VIEW CONCURRENTLY` tarda ~3,3 s y no bloquea lecturas concurrentes.
- **Implicancia de la vigencia:** entre un REFRESH y el siguiente, la MV refleja el estado al momento del último refresco: los pedidos nuevos de ese intervalo **no** aparecen hasta el próximo `REFRESH`. Para el usuario eso significa que el reporte puede estar atrasado hasta un mes — aceptable para un corte contable mensual, pero **no** aceptable si se quisiera usar para consultas operativas del día (en ese caso debería usarse la consulta base o refrescarse con más frecuencia: diaria/on-demand).
- Período recomendado según uso: corte mensual → refresh mensual; si se consulta la MV en el medio del mes para un informe parcial, refrescar justo antes de esa consulta puntual.

## 5. Índice descartado por sobreindexación

Spec: `spec_indice_descartado_producto_categoria.md`.

La IA propuso `CREATE INDEX idx_producto_categoria ON producto (categoria_id);`. **Se descartó** porque:
1. **Redundante**: ya existe `idx_producto_categoria_activo (categoria_id, activo)` de la Semana 3, que cubre cualquier consulta por `categoria_id` (con o sin filtro de vigencia).
2. **Costo sin beneficio**: agregar un segundo índice para el mismo acceso implica el doble de mantenimiento de escritura sin que el plan cambie.
3. La consulta por `categoria_id` ya usa `Bitmap Index Scan` sobre el índice existente (no hay Seq Scan a corregir).