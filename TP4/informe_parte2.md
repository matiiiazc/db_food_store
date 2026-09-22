# TP4 — Parte 2: Lectura crítica de planes de join interpretados por IA

Se tomó el plan real de la **Consulta 1** (facturación por categoría y mes), el cual contiene **tres nodos de join** (3 Hash Joins encadenados). Se le pasó a la IA **solo el texto del plan** (sin la consulta, sin stats de la base) pidiéndole una explicación nodo por nodo.

## Plan real utilizado (resumen)

```
Incremental Sort (rows=600000, actual 60, time 4141..4359 ms)
  Presorted Key: mes
  → GroupAggregate (Group Key: mes, c.nombre, actual 60)
    → Sort (external merge, Disk 20160kB, actual 600000 filas)
      → Hash Join (Condition: pr.categoria_id = c.id)   [nodo 3]
        Hash (rows=4) → Seq Scan categoria
        → Hash Join (Condition: dp.producto_id = pr.id) [nodo 2]
          Hash (rows=50000) → Seq Scan producto
          → Hash Join (Condition: dp.pedido_id = p.id)  [nodo 1]
            → Seq Scan detalle_pedido (600000)
            Hash (rows=200000) → Seq Scan pedido
Execution Time: 4387.557 ms
```

## Explicación de la IA (textual)

> "El plan arranca ordenando las 600.000 filas por mes y luego agrupa por mes y categoría. Después de la agregación hace tres «Nested Loop» que unen la tabla de detalle con pedido, con producto y con categoría. En el primer join, la tabla externa es `detalle_pedido`, que se escanea completa, y por cada fila se hace una búsqueda en `pedido` por índice. El segundo join une contra `producto` y el tercero contra `categoría`, ambas también escaneadas completas. El nodo más caro es el `Hash Join` contra `categoria` porque es el último que recibe 600.000 filas y su costo indicado (38.088) refleja el tiempo total de la consulta."

## Contrastación contra el plan real

La explicación contiene **tres imprecisiones reales**:

1. **No son Nested Loop sino Hash Joins.** La IA dice que el plan usa «Nested Loop» con tabla externa/interna y búsqueda por índice en cada fila. El plan real usa **Hash Join** en los tres cruces: primero se construye un `Hash` (build) sobre la tabla más chica y luego se hace el probe. No hay búsquedas por índice ni Nested Loop.
2. **Orden de los joins: no hay join contra `categoria` como "último que recibe 600.000".** El plan muestra que el join con `categoria` (el más externo) recibe los 600.000 de detalle×producto y los cruza con un hash de **4 filas** (`Hash (rows=4) → Seq Scan categoria`), no con 50.000. La IA no identifica qué tabla es el build (interna) y cuál el probe (externa) en cada hash.
3. **Confunde estimated cost con tiempo total.** La IA afirmó que el costo `38088` del Hash Join «refleja el tiempo total de la consulta». Ese número es el **costo estimado** (cost units, unidades abstractas del optimizador) del nodo `Hash Join` intermedio, no milisegundos ni el tiempo total. El tiempo real total es `Execution Time: 4387 ms`. La IA también usó el número 600.000 (que es la estimación de filas) como si fuera realidad, cuando en el plan real el resultado es de 60 filas.

## Tabla de hallazgos

| Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real |
|---|---|---|
| "El plan usa Nested Loop para unir detalle_pedido con pedido, buscando por índice en cada fila" | No | El plan real usa **Hash Join** en los tres nodos (`Hash Join  (cost=7144..28334)`, `Hash Cond: (dp.pedido_id = p.id)`). No hay Nested Loop y no se usa índice en estas uniones. |
| "La tabla externa es detalle_pedido y por cada fila se busca en pedido por índice" | No | En un Hash Join no hay "externa/interna" como en Nested Loop; el plan real construye un **Hash sobre `pedido` (`Hash ... rows=200000`)** y hace probe con `detalle_pedido`. Definir "externa" como detalle y "interna" buscada por índice es una interpretación de Nested Loop que no aplica. |
| "El tercer join contra `categoria` recibe 600.000 filas y su costo 38088 es el tiempo total" | No | El join contra `categoria` recibe 600.000 filas (correcto) pero su build es un **Hash de solo 4 filas** (`Hash (rows=4) → Seq Scan categoria`). Y `38088.01` es el **costo estimado** (cost units) del nodo, no ms ni el tiempo total: el `Execution Time` real es **4387.557 ms**. |
| "El nodo de agregación ordena 600.000 filas por mes y categoría" | Sí | El plan muestra `Sort ... external merge Disk: 20160kB` sobre 600.000 filas con Sort Key del mes y `c.nombre`, seguido de `GroupAggregate` con ese Group Key. |

## Conclusión

La lectura crítica detectó **3 imprecisiones** reales en la explicación de IA sobre un plan de join:

- la IA **confundió Hash Join con Nested Loop** (no identificó correctamente build/probe, y afirmó búsquedas por índice que no existen en el plan);
- **no identificó correctamente cuál tabla es la que se buildea en el hash** (dijo que `categoria` recibe 600.000 y "es la más cara", cuando su build es de 4 filas);
- **confundió el costo estimado de un nodo intermedio (38088 cost units) con el tiempo total de la consulta**, que en realidad es 4387 ms.

Esto refuerza el criterio de la cátedra: las explicaciones de la IA sobre planes de join deben contrastarse siempre contra el texto real del plan, nodo por nodo y número por número.