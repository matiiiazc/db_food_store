# Objetivos 1 y 2 — Modelo ER y paso a modelo relacional

Proyecto **Food Store** — sistema de gestión de pedidos de un negocio de comidas.
Enunciado original: TP1 (PDF oficial de la cátedra). Este documento lo extrae del entregable oficial y lo concilia con el `schema.sql` ejecutado en PostgreSQL.

---

## 1. Modelo entidad-relación (objetivo 1)

### 1.1 Reglas de negocio del enunciado (R1–R7)

| Regla | Enunciado |
|---|---|
| R1 | Todo producto pertenece **exactamente a una** categoría; una categoría puede tener muchos productos o **ninguno** todavía. |
| R2 | Todo pedido pertenece **exactamente a un** cliente; un cliente puede no haber hecho ningún pedido o haber hecho varios. |
| R3 | Un pedido puede incluir **varios productos distintos** y un producto puede aparecer en **muchos pedidos** (relación **N:M** pedido–producto). |
| R4 | De cada producto en un pedido se registra **cantidad** y **precio_unitario** (el precio de lista puede cambiar; no debe alterar pedidos ya facturados). |
| R5 | Un producto no puede tener **stock ni precio negativos**. |
| R6 | Cada cliente tiene un **email único** (clave candidata). |
| R7 | **Borrado lógico**: no se eliminan físicamente productos ni categorías; se marcan `activo = FALSE` (preservar historial). |

### 1.2 Entidades, atributos, claves y tipos conceptuales

**CATEGORIA** — entidad fuerte
- `id` (numérico) **PK**
- `nombre` (texto, único)
- `activo` (booleano, por R7)
- `created_at` (fecha/hora)

**CLIENTE** — entidad fuerte
- `id` (numérico) **PK**
- `nombre` (texto), `apellido` (texto)
- `email` (texto) **clave candidata** (R6)
- `telefono` (texto, opcional)
- `created_at` (fecha/hora)

**PRODUCTO** — entidad fuerte
- `id` (numérico) **PK**
- `nombre` (texto), `descripcion` (texto, opcional)
- `precio` (numérico, ≥ 0 por R5)
- `stock` (entero, ≥ 0 por R5)
- `activo` (booleano, por R7)
- `categoria_id` (FK hacia CATEGORIA)

**PEDIDO** — entidad fuerte
- `id` (numérico) **PK**
- `fecha` (fecha/hora con zona horaria)
- `forma_pago` (dominio cerrado: EFECTIVO / TARJETA / TRANSFERENCIA)
- `cliente_id` (FK hacia CLIENTE)

**DETALLE_PEDIDO** — entidad asociativa (materializa R3)
- `id` (numérico) **PK** (clave sustituta; justificación en sección 2)
- `pedido_id` (FK hacia PEDIDO)
- `producto_id` (FK hacia PRODUCTO)
- `cantidad` (entero, > 0)
- `precio_unitario` (numérico, precio **congelado** al momento de la venta — R4)
- `subtotal` (numérico = cantidad × precio_unitario)

### 1.3 Relaciones, cardinalidad y participación

| Relación | Cardinalidad | Participación | Regla que la justifica |
|---|---|---|---|
| CATEGORIA — PRODUCTO | **1:N** (1 categoría → N productos) | Categoría: **parcial** (una categoría puede no tener productos). Producto: **total** (todo producto pertenece a una categoría). | R1 |
| CLIENTE — PEDIDO | **1:N** (1 cliente → N pedidos) | Cliente: **parcial** (puede no haber pedido). Pedido: **total** (todo pedido tiene cliente). | R2 |
| PEDIDO — PRODUCTO | **N:M** (resuelta con DETALLE_PEDIDO) | Ambas parciales respecto de la entidad asociativa (un pedido puede estar vacío; un producto puede no venderse nunca). Atributos propios de la relación: `cantidad`, `precio_unitario`, `subtotal` (R3, R4). | R3, R4 |

### 1.4 Respuestas a las preguntas guía del TP1

**¿Por qué PEDIDO–PRODUCTO no puede ser 1:N directa?**
Porque un mismo producto (ej. «Muzzarella») se vende en muchos pedidos y un pedido lleva varios productos. Si se modelara 1:N, los atributos de la línea (`cantidad`, `precio_unitario`) no tendrían dónde vivir sin duplicar filas de pedido, y el **precio por transacción** (R4) no quedaría registrado. Se pierde entonces el dato de *cuánto se facturó por cada producto en cada pedido* y el histórico de precios.

**¿Qué entidad es parcial con categoría y cuál total?**
Participación **parcial**: `categoria` (puede estar recién creada sin productos). Participación **total**: `producto` (`categoria_id NOT NULL`). Si se invirtiera —categoría con participación total— no se podría crear una categoría vacía, y un producto sin categoría sería imposible de insertar; contradice R1.

**¿Descomponer atributos compuestos?**
Sí: `nombre_completo` del cliente se descompuso en `nombre` y `apellido` (facilita búsquedas y reportes — los TPs posteriores filtran por `apellido`). El `nombre` de producto es atómico (no se usa compuesto por partes). Todo se documenta en el diccionario de datos.

---

## 2. Paso de ER a modelo relacional (objetivo 2)

### 2.1 Reglas de derivación aplicadas

1. **Entidad fuerte → tabla** con su PK.
2. **Relación 1:N → FK en el lado N**: `producto.categoria_id → categoria.id`, `pedido.cliente_id → cliente.id`.
3. **Relación N:M → tabla intermedia (entidad asociativa)**: `detalle_pedido` con FKs a `pedido` y `producto` + atributos propios de la relación (`cantidad`, `precio_unitario`, `subtotal`).
4. Claves sustitutas (`GENERATED ALWAYS AS IDENTITY`) en las 5 tablas. En DETALLE_PEDIDO se eligió **clave sustituta** `id` en vez de la compuesta `(pedido_id, producto_id)`: simplifica referencias externas futuras y evita FK compuestas; la unicidad lógica `(pedido_id, producto_id)` se preserva con una restricción **UNIQUE** (ver `schema.sql`, `uq_detalle_pedido_producto`).

### 2.2 Esquema relacional derivado (notación del TP1)

```
categoria (id, nombre, activo, created_at)
cliente   (id, nombre, apellido, email, telefono, created_at)
producto  (id, nombre, descripcion, precio, stock, activo, categoria_id -> categoria.id)
pedido    (id, fecha, forma_pago, cliente_id -> cliente.id)
detalle_pedido (id, pedido_id -> pedido.id, producto_id -> producto.id,
                cantidad, precio_unitario, subtotal)
```
(las claves primarias están subrayadas en el entregable gráfico; aquí se marcan con `id` y las FKs con `->`).

### 2.3 Preguntas guía del TP1

**¿Qué pasa si la tabla intermedia no lleva ambas FK como NOT NULL?**
Se perdería la integridad de la relación N:M: un detalle sin `pedido_id` o sin `producto_id` rompería la participación total de la relación y permitiría «filas huérfanas» que no unen nada (un detalle que no pertenece a ningún pedido o que no referencia ningún producto). El CHECK `cantidad > 0` tampoco se podría garantizar sensatamente.

**¿Un pedido vacío cambia la participación?**
En el modelo elegido, `detalle_pedido.pedido_id` es NOT NULL pero `pedido` **no** exige tener líneas (la PK de `pedido` existe independientemente). Si el negocio permitiera pedidos recién iniciados sin productos (participación **parcial** de `pedido` respecto de la relación N:M), el diseño actual ya lo soporta: la participación **total** solo rige desde el lado del detalle (todo detalle pertenece a un pedido). Invirtiendo eso —exigir todo pedido con al menos una línea— haría falta un CHECK con subconsulta (restringido en motor) o un patrón transaccional en la app.

---

## 3. Conciliación con el DDL real

El `schema.sql` (y su copia `ddl.sql` en esta carpeta) **implementa exactamente** este modelo relacional:
- ENUM `forma_pago_enum` (dominio cerrado de `forma_pago`).
- PK explícita IDENTITY en las 5 tablas.
- FK con `ON DELETE RESTRICT` (R7 + red de seguridad de historial).
- UNIQUE `uq_categoria_nombre`, `uq_cliente_email`, `uq_detalle_pedido_producto`.
- CHECK `precio ≥ 0`, `stock ≥ 0`, `cantidad > 0`, subtotales ≥ 0 (R5).
- Índices `idx_categoria_activo`, `idx_producto_categoria_activo`, `idx_pedido_cliente`, `idx_detalle_pedido`, `idx_detalle_producto` (consultas de uso esperado).
- `activo BOOLEAN NOT NULL DEFAULT TRUE` (R7) en `categoria` y `producto`.