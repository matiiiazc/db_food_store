# TP5 — Índices, Vistas y Vistas Materializadas

Unidad 3, Semana 5 · Food Store · PostgreSQL 18 · Esquema R7 (raíz `schema.sql`) · Base `food_store_tp3`.

## Contenido

- **Parte A — Plan de indexado (con IA):** 3 índices justificados en `specs/`, con `EXPLAIN ANALYZE` antes/después. Una propuesta de índice de la IA fue **descartada por sobreindexación** (detail en informe y en el spec correspondiente).
- **Parte B — Vistas:** 3 vistas para reportes (catálogo vigente, pedidos-cliente, detalle de pedido), cada una **verificada equivalente** a su consulta manual (0 filas de diferencia; conteos: 50.000 / 200.000 / 600.000).
- **Parte C — Vista materializada:** facturación por categoría y mes, ~**193×** más rápida que el reporte base (14,6 ms vs 2824 ms), con índice único para `REFRESH CONCURRENTLY` implementado.

## Archivos

| Archivo | Descripción |
|---|---|
| `indices.sql` | CREATE INDEX de la Parte A (los 3 aceptados) |
| `views.sql` | Vistas + vista materializada + índice único |
| `informe_mediciones.md` | Mediciones antes/después, costo de escritura, equivalencias y frecuencia de refresco |
| `specs/` | 8 specs (3 índices, 1 descarte, 3 vistas, 1 MV) |
| `duia.md` | Documentación de uso de IA (Kiro y OpenCode) |
| `README.md` | Este archivo |

## Resumen de resultados

### Índices (Parte A)

| Índice | Antes | Después | Ganancia |
|---|---|---|---|
| `idx_producto_nombre_vig` (parcial `activo`, `text_pattern_ops`) | Seq Scan · 20,0 ms | Bitmap Index · 14,4 ms | Seq → Bitmap, prefijo indexado |
| `idx_cliente_apellido` (B-tree) | Seq Scan · 6,8 ms | Index Scan · 0,2 ms | **~31×** |
| `idx_pedido_forma_fecha` (compuesto) | rechecks (10.375) · 26,8 ms | 0 rechecks · 20,5 ms | Index Cond plena |

Costo de escritura (300 INSERT en `pedido`): 47,5 ms → 151,6 ms (+3,2×, esperado por mantenimiento de índices). Descartado: `idx_producto_categoria` (redundante con `idx_producto_categoria_activo` de la Semana 3).

### Vistas (Parte B)

- `vista_productos_vigentes` — catálogo vigente + nombre de categoría (50.000 filas).
- `vista_pedidos_cliente` — pedidos con datos del cliente, **sin** `telefono` (seguridad) (200.000 filas).
- `vista_detalle_pedido` — líneas con nombre de producto; no filtra por producto inactivo para preservar el histórico (600.000 filas).

Verificación de equivalencia: conteo idéntico y `EXCEPT` = 0 en las tres.

### Vista materializada (Parte C)

- `mv_facturacion_categoria_mes` — facturación por categoría y mes: **14,6 ms** (base: 2824 ms).
- Índice único `(mes, categoria)` → `REFRESH MATERIALIZED VIEW CONCURRENTLY` verificado (~3,3 s).
- Frecuencia recomendada: mensual (corte contable). Vigencia: los datos quedan congelados al último refresco.

## Reproducción

```bash
psql -U postgres -d food_store_tp3 -f indices.sql
psql -U postgres -d food_store_tp3 -f views.sql
```

> Los índices y objetos se crean sobre el esquema de `schema.sql`; se usó la base masiva `food_store_tp3` (50.000 productos, 20.000 clientes, 200.000 pedidos, 600.000 detalles).