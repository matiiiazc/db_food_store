# TP5 — DUIA (Documentación de Uso de la Inteligencia Artificial)

Unidad 3, Semana 5 — Índices, vistas y vistas materializadas en Food Store.

## 1. Herramientas y roles

| Herramienta | Rol |
|---|---|
| **OpenCode** (asistente de código, modelo big-pickle) | IA primaria de asistencia: redactó los specs, los scripts `indices.sql`/`views.sql` y este informe, realizó/sugirió las consultas de medición y las verificaciones de equivalencia. |
| **PostgreSQL 18** (motor real) | Verificación empírica: cada afirmación (planes de ejecución, tiempos, filas, equivalencias) fue validada con `EXPLAIN ANALYZE` y consultas reales sobre `food_store_tp3`. |
| **Git + GitHub** | Control de versiones y entrega (commits parciales por tipo de objeto en el repositorio `db_food_store`). |

## 2. Herramienta de asistencia IA (Kiro)

El flujo de trabajo de la materia plantea la herramienta **Kiro**. En esta máquina **Kiro no está instalado** (fue desinstalado por el usuario), por lo que **no pudo utilizarse en este TP**. 

**Alternativa aplicada:** los specs se redactaron manualmente siguiendo la estructura típica de las specs de Kiro (objetivo → consulta afectada → columnas candidatas → tipo propuesto → criterio de aceptación), como en los TP anteriores. La generación de propuestas de índice/vista fue realizada por OpenCode actuando como IA de asistencia y luego verificada en el motor real.

## 3. Interacción IA ↔ humano ↔ motor

1. La IA propuso los objetos a crear (3 índices, 3 vistas, 1 vista materializada).
2. Toda propuesta fue verificada en PostgreSQL 18 con `EXPLAIN ANALYZE` antes/después y comparaciones de resultados (EXCEPT/conteo).
3. Se descartó una propuesta de la IA por sobreindexación (ver `specs/spec_indice_descartado_producto_categoria.md`).
4. Decisiones del humano adoptadas:
   - Definir como "consulta víctima" para alfabeto/prefijo una búsqueda real de catálogo (`LIKE 'Producto 1%'`).
   - Elegir el índice compuesto `(forma_pago, fecha)` (igualdad + rango) en lugar de un índice solo sobre `forma_pago` (baja cardinalidad).
   - No filtrar por vigencia del producto en la vista de detalle de pedido (preservar el histórico facturado).

## 4. Errores o imprecisiones de la IA detectados

- La IA sugirió crear `idx_producto_categoria ON producto (categoria_id)` sin advertir que ya existía `idx_producto_categoria_activo` de la Semana 3 cubriendo ese acceso. **Detectado por revisión humana → descartado.**
- En el primer intento de verificación de las vistas, la consulta se armó con múltiples comandos en un solo `-c` y psql no los interpretó correctamente; se reformuló como script por stdin. (Incidente del verificador, no del motor.)

## 5. Traducción de la consigna al esquema real (R7)

El enunciado de la cátedra menciona tablas/columnas que **no existen** en el esquema real (`usuario`, `estado`, `eliminado`, `idx_pedido_usuario`, `idx_producto_categoria`). Se tradujeron al esquema real de Food Store:

| Enunciado (genérico) | Esquema real (Food Store) |
|---|---|
| Búsqueda por `usuario` | `cliente` (búsqueda por `apellido`) |
| Filtro por `estado`/`eliminado` | `activo` (baja lógica en `categoria` y `producto`) |
| `idx_pedido_usuario` (pedidos de un cliente) | ya cubierto por `idx_pedido_cliente` (Semana 3) |
| `idx_producto_categoria` (Índice 1, Semana 4 handout) | ya cubierto por `idx_producto_categoria_activo` (por eso se descartó su propuesta) |

## 6. Resultados

- 3 índices creados con ganancia de plan (Seq → Index/Bitmap) y tiempos verificados; 1 propuesta descartada por sobreindexación.
- 3 vistas verificadas equivalentes a sus consultas manuales (0 filas de diferencia).
- 1 vista materializada: ~193× más rápida que el reporte base, con índice único para `REFRESH CONCURRENTLY`.

## 7. Archivos entregados

```
TP5/
  indices.sql                    -> Índices de la Parte A
  views.sql                      -> Vistas (Parte B) y vista materializada (Parte C)
  informe_mediciones.md          -> Mediciones antes/después y balance de escritura
  duia.md                        -> Este documento
  README.md                      -> Resumen estructurado del TP
  specs/
    spec_indice_producto_nombre_vig.md
    spec_indice_cliente_apellido.md
    spec_indice_pedido_fecha_forma_pago.md
    spec_indice_descartado_producto_categoria.md
    spec_vista_productos_vigentes.md
    spec_vista_pedidos_cliente.md
    spec_vista_detalle_pedido.md
    spec_vista_materializada_facturacion.md
```
Schema heredado: `schema.sql` (raíz del repo). Base de datos utilizada: `food_store_tp3`.