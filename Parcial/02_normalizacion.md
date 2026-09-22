# Objetivo 3 — Normalización hasta 3FN/BCNF

Domino: planilla plana real de Food Store (una fila por línea de producto vendido en un pedido).
Tomada del enunciado oficial del TP1.

## Planilla original (relación universal VENTAS)

| pedido_id | fecha | cliente | producto | categoria | precio_unitario | cant | subtotal | forma_pago |
|---|---|---|---|---|---|---|---|---|
| 1 | 01/03/2026 | Ana Gómez | Muzzarella | Pizzas | 1000.00 | 2 | 2000.00 | EFECTIVO |
| 1 | 01/03/2026 | Ana Gómez | Coca 1.5L | Bebidas | 800.00 | 1 | 800.00 | EFECTIVO |
| 2 | 01/03/2026 | Luis Paz | Napolitana | Pizzas | 1500.00 | 1 | 1500.00 | TARJETA |
| 3 | 05/03/2026 | Ana Gómez | Muzzarella | Pizzas | 1050.00 | 3 | 3150.00 | TRANSFERENCIA |
| 4 | 06/03/2026 | Marta Ruiz | Coca 1.5L | Bebidas | 800.00 | 4 | 3200.00 | EFECTIVO |
| 4 | 06/03/2026 | Marta Ruiz | Napolitana | Pizzas | 1500.00 | 2 | 3000.00 | EFECTIVO |
| 5 | 07/03/2026 | Luis Paz | Muzzarella | Pizzas | 1050.00 | 1 | 1050.00 | TARJETA |

Reglas de negocio adicionales:
- Cada pedido tiene una única fecha, un único cliente y una única forma de pago.
- Cada producto pertenece a una única categoría.
- Dentro de un mismo pedido, un producto no se repite en más de una línea.
- El precio de un producto puede variar en el tiempo (nótese: la Muzzarella va de 1000.00 a 1050.00).

---

## Paso 1 — Claves candidatas

Dado que **dentro de un mismo pedido un producto no se repite**, cada fila queda identificada de forma única por el par:

**`(pedido_id, nombre_producto)`**  → clave candidata (compuesta)

Ningún otro conjunto mínimo la identifica: `pedido_id` solo no alcanza (pedidos 1 y 4 tienen dos líneas); `nombre_producto` solo no alcanza (la Muzzarella aparece 3 veces).

## Paso 2 — Dependencias funcionales

Usando notación `X → Y` («X determina Y»), sobre la planilla y las reglas de negocio:

1. `pedido_id → fecha, cliente, forma_pago`  (cada pedido tiene una sola fecha/cliente/forma de pago)
2. `nombre_producto → categoria`  (cada producto tiene una sola categoría)
3. `(pedido_id, nombre_producto) → cant, precio_unitario, subtotal`  (la línea fija la cantidad y el precio de esa venta)
4. `(pedido_id, nombre_producto) → precio_unitario` **solo de la combinación** — el precio unitario **no** depende del producto solo, porque cambia entre pedidos (1000 vs 1050). Depende del producto **al momento de esa venta** (R4): la pareja `pedido+producto` es quien lo determina.
5. `cant × precio_unitario = subtotal` (derivable; se mantiene por trazabilidad histórica — R4 del TP1).

Resultado de la DF clave para el razonamiento:

```
(pedido_id, nombre_producto)  →  cant, precio_unitario, subtotal
pedido_id                     →  fecha, cliente, forma_pago
nombre_producto               →  categoria
```

## Paso 3 — Verificación de 1FN

**¿Cumple 1FN? Sí.** Todos los atributos tienen valores atómicos (una sola fecha, un solo precio, una sola cantidad por celda); no hay grupos repetidos ni listas dentro de celdas. No requiere corrección.

## Paso 4 — Verificación de 2FN (dependencia parcial)

2FN exige 1FN y que **ningún atributo no clave dependa de una parte de la clave compuesta**.

Detectamos dependencias parciales (violan 2FN):
- `pedido_id → fecha, cliente, forma_pago`: estos atributos dependen de **una sola parte** de la clave `(pedido_id, nombre_producto)`.
- `nombre_producto → categoria`: depende de la **otra parte** de la clave.

**Corrección** — se separan en sus propias tablas:
- `PEDIDO(pedido_id, fecha, cliente, forma_pago)` — clave `pedido_id`.
- `PRODUCTO_CATEGORIA(nombre_producto, categoria)` — clave `nombre_producto`.
- La relación entre ambas queda solo con la FK:

**`VENTAS_LINEA(pedido_id, nombre_producto, cant, precio_unitario, subtotal)`**
con clave `(pedido_id, nombre_producto)`, FKs a `PEDIDO` y a `PRODUCTO_CATEGORIA`.

## Paso 5 — Verificación de 3FN (dependencia transitiva)

3FN exige 2FN y que **ningún atributo no clave dependa transitivamente de la clave** (a través de otro no clave).

- En `VENTAS_LINEA`: `cant`, `precio_unitario`, `subtotal` dependen solo de la clave `(pedido_id, nombre_producto)`. No hay transitividad. ✅
- En `PEDIDO`: `fecha`, `cliente`, `forma_pago` dependen de `pedido_id`. No hay dependencia transitiva. ✅
- En `PRODUCTO_CATEGORIA`: `categoria` depende de `nombre_producto` directamente. ✅

No hay correcciones por aplicar en este paso.

## Paso 6 — Verificación de BCNF

BCNF: **todo determinante de una DF no trivial debe ser clave candidata**.

- `VENTAS_LINEA`: el único determinante es `(pedido_id, nombre_producto)`, que es la clave candidata. ✅
- `PEDIDO`: el único determinante es `pedido_id` (clave). ✅
- `PRODUCTO_CATEGORIA`: el único determinante es `nombre_producto` (clave). ✅

**Resultado: el esquema está en BCNF.** No se encontró ningún determinante que no sea clave candidata, por lo que BCNF se cumple explícitamente (no hubo excepciones que corregir).

## Paso 7 — Esquema final normalizado

```
PEDIDO          (pedido_id, fecha, cliente, forma_pago)              -- clave: pedido_id
PRODUCTO_CATEGORIA (nombre_producto, categoria)                      -- clave: nombre_producto
VENTAS_LINEA    (pedido_id, nombre_producto, cant, precio_unitario, subtotal)
                -- clave: (pedido_id, nombre_producto), FK -> PEDIDO, FK -> PRODUCTO_CATEGORIA
```

## Pregunta de integración — conciliación con el modelo ER/relacional

| Tabla normalizada (de datos) | Entidad del ER | Esquema real (schema.sql) |
|---|---|---|
| PEDIDO | PEDIDO | `pedido` (id, fecha, forma_pago, cliente_id) |
| PRODUCTO_CATEGORIA | PRODUCTO + CATEGORIA | `producto` (…, categoria_id → `categoria`) |
| VENTAS_LINEA | DETALLE_PEDIDO (entidad asociativa) | `detalle_pedido` (…, cantidad, precio_unitario, subtotal) |

**¿Hay atributos del ER que no estaban en la planilla?** Sí: `email` del cliente (R6), `telefono`, `descripcion` del producto, `stock`. La planilla histórica no los registraba porque solo guardaba lo vendido, no datos de identidad ni inventario.

**Qué enseña la diferencia:** modelar desde el enunciado (ER) captura *todo* lo que el negocio necesita (incluso lo que aún no hay en datos); normalizar desde datos históricos descubre la estructura *mínima* que explica lo existente. Los dos caminos convergen al mismo esquema base, y las partes 2 y 3 del TP1 produjeron las mismas tablas — diferencia esperable: el ER porta más atributos que la planilla.

**Nota sobre `subtotal` almacenado:** es calculable como `cant × precio_unitario`. Almacenarlo **no viola** ninguna forma normal (no crea dependencia de la clave distinta de la existente); es una decisión de trazabilidad histórica y rendimiento: si el precio cambiara, el `subtotal` de la venta ya facturada debe quedar congelado (R4). Es consistente con el esquema real (`detalle_pedido.subtotal`).