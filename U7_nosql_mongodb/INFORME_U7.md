# TP Unidad 7 — NoSQL y nuevas formas de almacenamiento (Food Store)

**Asignatura:** Bases de Datos II · Tecnicatura Universitaria en Programación (UTN)
**Motores:** PostgreSQL 18 (`food_store_tp3`) y MongoDB (colección documental)
**Subconjunto:** 5 pedidos existentes y sus detalles (pedidos `id` 1–5).
**Entregables de código:** `migracion_pedidos.js`, `consultas_mongodb.js`, `consultas_postgresql.sql` (+ `ejecutar_mongodb.py`).

> Ejecución real: la migración y las consultas (a)–(d) se ejecutaron **realmente** contra MongoDB **9.0.4** en `127.0.0.1:27017` (servicio `MongoDB` en ejecución), usando `pymongo` (script `ejecutar_mongodb.py`, equivalente a `insertMany`/`find`; los `.js` son ejecutables también con `mongosh --file`). Evidencia: `evidencia_mongodb.txt`. La verificación relacional se ejecutó en PostgreSQL (ver `evidencia_postgresql.txt`) y coincide en cantidad e IDs.

## Parte 1 — Modelo documental y migración

### Consigna 1. Subconjunto, tablas/claves en PostgreSQL y esquema documental

**Tablas y claves (PostgreSQL, versión real):**
- `pedido(id PK, fecha, forma_pago [enum], cliente_id FK→cliente.id, created_at, eliminado)` — cabecera del pedido.
- `detalle_pedido(id PK, pedido_id FK→pedido.id, producto_id FK→producto.id, cantidad, precio_unitario, subtotal, eliminado, UNIQUE(pedido_id,producto_id))` — líneas.
- `cliente(id PK, nombre, apellido, email UNIQUE, telefono, created_at)` — datos del cliente.
- `producto(id PK, nombre, ...)` — se toma el nombre del producto para la línea.

Relación: un `pedido` pertenece a un `cliente` (N:1) y tiene N `detalle_pedido`; cada detalle referencia un `producto` (N:1).

**Colección propuesta:** `food_store_nosql.pedidos` (un documento = un pedido completo).

| Campo | Tipo / forma | Origen / nota |
|---|---|---|
| `_id`, `id_origen` | entero | `pedido.id` preservado (trazabilidad con el origen) |
| `fecha` | ISODate | `pedido.fecha` |
| `forma_pago` | string | enum de origen |
| `estado` | string | derivado de `pedido.eliminado` (`ACTIVO`/`ANULADO`) |
| `total` | Decimal128 | suma de subtotales históricos del pedido (almacenado para consulta) |
| `cliente` | **objeto embebido** `{id_origen,nombre,apellido,email}` | snapshot del cliente al migrar |
| `lineas` | **arreglo** de objetos `{producto_id,producto,cantidad,precio_unitario,subtotal}` | líneas embebidas, 1..N |

### Consigna 2. Base, colección y migración (≥ 5 pedidos)

Implementado en `migracion_pedidos.js`: `use('food_store_nosql')`, `db.pedidos.drop()` y `db.pedidos.insertMany([...])` con 5 documentos (ids 1–5). Cada documento incluye fecha, estado, cliente, productos (nombre+id), cantidades y **precios históricos** (`precio_unitario`, `subtotal`, `total`). Identificadores de origen conservados (`_id`/`id_origen`, `cliente.id_origen`, `producto_id`). Importes/cantidades respetados desde PostgreSQL.

### Consigna 3. Dos reglas de integridad conservadas y decisión de embebido

1. **Precios/cantidades históricos inmutables:** `precio_unitario` y `subtotal` se copian tal como constan en `detalle_pedido` (no se recalculan desde `producto.precio` actual). Así un cambio posterior de precio en catálogo no altera pedidos ya facturados (misma regla de negocio R4 del modelo relacional). `total` se almacena coherente con esos subtotales.
2. **Trazabilidad de identificadores y pertenencia pedido–líneas:** se preservan `id_origen` (pedido), `cliente.id_origen` y `producto_id`. Cada línea queda asociada a su pedido por estar dentro del mismo documento (equivalente a la FK `detalle_pedido.pedido_id`), evitando líneas huérfanas dentro del subconjunto migrado.

**Qué se embebió y por qué:** `cliente` (objeto) y `lineas` (arreglo) se incluyeron **dentro** del documento del pedido, en lugar de colecciones separadas, porque el acceso frecuente es “pedido completo” (cabecera + cliente + líneas) en una sola lectura, sin `$lookup`/JOIN. El patrón de embedding para relaciones contenidas “one-to-few/many” de un pedido es el recomendado cuando se consulta el agregado junto (documentación MongoDB, *Embedded Data Models*). No se embebió el catálogo completo de `producto`/`cliente` como entidades maestras globales: solo el snapshot necesario del pedido, evitando duplicación masiva y manteniendo coherencia histórica.

## Parte 2 — Consultas y verificación

### Consigna 4. Consultas MongoDB (ver `consultas_mongodb.js`)

- **(a) Todos los pedidos (id y estado):** `find({}, {id_origen:1, estado:1})` → ids 1–5, estado `ACTIVO`.
- **(b) Filtrar por estado existente:** `find({estado:"ACTIVO"})` → estado seleccionado `ACTIVO`, **cantidad 5**, IDs `1,2,3,4,5`.
- **(c) Pedidos que contienen un producto:** `find({"lineas.producto":"Producto 16"})` (equivalente `lineas.producto_id:16`) → producto `Producto 16`, **cantidad 1**, ID `2`.
- **(d) Total superior a un umbral:** `find({total: {$gt: NumberDecimal("30000")}})`. **Umbral 30000.** Justificación: los totales son 27724.48, 45193.22, 49020.34, 21370.25, 35496.55 (promedio ≈ 35760,93); 30000 separa tickets bajos (1,4) de tickets altos (2,3,5) para un análisis comercial simple del subconjunto. Resultado: **cantidad 3**, IDs `2,3,5`.

### Consigna 5. Equivalentes PostgreSQL y comparación (ejecutado; `evidencia_postgresql.txt`)

Equivalentes (b) y (c) en `consultas_postgresql.sql`, acotados al subconjunto migrado (`id IN (1..5)`) para una comparación verificable. Ejecución real con `psql`.

| Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB (ejecución real) | Coinciden los IDs |
|---|---:|---:|:---:|
| Estado seleccionado: `ACTIVO` | 5 | 5 | **Sí** — {1,2,3,4,5} |
| Producto seleccionado: `Producto 16` | 1 | 1 | **Sí** — {2} |

**Diferencias:** no se detectaron diferencias en cantidad ni en identificadores. La coincidencia se explica porque la migración preservó `id_origen` y copió los valores históricos/estado sin transformación, y los filtros son semánticamente equivalentes (`eliminado=false` ↔ `estado:"ACTIVO"`; join a `producto.nombre` ↔ match sobre `lineas.producto` embebido). No fue necesario corregir modelo ni consultas.

## Parte 3 — Evaluación de la tecnología e IA

### Consigna 6. Consulta realizada a la IA (comparación)

> *Consulta (herramienta de IA):* “En un sistema Food Store con modelo relacional actual (PostgreSQL, tablas pedido/detalle_pedido/cliente/producto), donde el acceso frecuente es leer pedidos completos y es necesario conservar la coherencia de cantidades y precios históricos, compará PostgreSQL y MongoDB para almacenar y consultar pedidos. Indicá ventajas y límites de cada uno.”

**Respuesta de IA (síntesis):**
- **Afirmación 1 (IA):** *“MongoDB permite obtener un pedido completo (cliente y líneas) en una sola consulta al embeber los datos, evitando los JOIN entre `pedido`, `detalle_pedido` y `cliente` que requiere PostgreSQL, lo que suele mejorar la lectura de agregados.”*
- **Afirmación 2 (IA):** *“PostgreSQL garantiza la integridad referencial y las restricciones del dominio (FK, CHECK, UNIQUE) de forma nativa entre tablas, mientras que en MongoDB esa integridad debe asegurarse en la aplicación o con validación de esquema, por lo que para cantidades y precios coherentes el modelo relacional es más seguro por defecto.”*

### Consigna 7. Contraste de dos afirmaciones y conclusión

**Contraste Afirmación 1.** Confirmada conceptualmente y por el laboratorio. MongoDB documenta el patrón de *embedded data models* para recuperar datos relacionados en una sola operación de base de datos y evitar `$lookup` cuando se accede al agregado junto (MongoDB Manual, *Embedded Data Models* / *Embedding MongoDB Documents For Ease And Performance*). En nuestro caso, (a)–(d) resuelven pedido+cliente+líneas con un único `find` sobre `pedidos`; el equivalente relacional de (c) requirió `JOIN pedido–detalle_pedido–producto`. Matiz: la ventaja depende del patrón de acceso; si se consultaran líneas o productos de forma independiente y masiva, el embedding duplicaría datos.

**Contraste Afirmación 2.** Confirmada. El esquema real PostgreSQL declara FK (`detalle_pedido.pedido_id→pedido`, `producto_id→producto`, `pedido.cliente_id→cliente`), `UNIQUE(pedido_id,producto_id)` y `CHECK` de cantidad/precios (ver `schema.sql`), que el motor impone. MongoDB ofrece validación de esquema (`$jsonSchema`) pero no integridad referencial nativa entre colecciones/documentos como las FK relacionales; la coherencia entre `lineas.producto_id` y un catálogo, o entre `total` y la suma de `subtotal`, recae en la lógica de escritura/importación (en la migración la verificamos contra la fuente). Para preservar cantidades y precios históricos la copia literal (snapshot) funcionó en ambos, pero las garantías estructurales por defecto son más fuertes en PostgreSQL.

**Conclusión (decisión fundamentada, ≤ 200 palabras).** Para el subconjunto “pedidos y detalle” de Food Store conviene **mantener PostgreSQL como fuente de verdad** y **usar MongoDB solo como vista documental complementaria** (CQRS/lectura) si se justifica por carga de consulta, no como reemplazo. *Criterio 1 — consistencia e integridad:* pedidos manejan importes, cantidades y relaciones con cliente/producto; PostgreSQL impone FK, CHECK, UNIQUE y transacciones ACID de forma nativa, reduciendo el riesgo de incoherencias que en MongoDB dependen de la aplicación/validación. *Criterio 2 — patrón de acceso:* el acceso a “pedido completo” se resuelve eficientemente en MongoDB con un documento embebido (una lectura, sin JOIN), como mostró el laboratorio; esto es útil para lectura/reporting. Dado que ambos devolvieron resultados idénticos sobre datos migrados correctamente, la ganancia de MongoDB es de modelo de lectura, no de corrección: la coherencia histórica se preservó porque se respetó la fuente. Por ello, la opción equilibrada es combinar tecnologías: transaccional y normativa en PostgreSQL; proyección documental en MongoDB para consultas de agregado, manteniendo sincronización controlada desde el origen relacional.