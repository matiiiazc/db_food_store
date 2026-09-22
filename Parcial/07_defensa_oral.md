# Defensa oral — TPI Food Store (primera entrega)

Guía de 1 hoja: cómo responder las preguntas típicas de defensa, con los números que ya tenés medidos.

---

## Elevator pitch (30 segundos)

> «Food Store es un sistema de gestión de pedidos para un negocio de comidas. Lo modelamos desde un enunciado de negocio (5 entidades, 1 relación N:M resuelta con tabla intermedia), lo normalizamos hasta BCNF, lo cargamos con datos masivos —200.000 pedidos y 600.000 líneas— y sobre eso probamos integridad, concurrencia y optimización contra el motor real (PostgreSQL 18). La IA (OpenCode) fue el motor de generación, pero todo se verificó antes de aceptar: validamos en el motor cada script, medimos antes/después y descartamos las propuestas que no mejoraban.»

## Preguntas típicas y respuestas cortas

### Modelo de datos (objs 1-4)
- **¿Por qué la relación pedido–producto es N:M?** Porque un pedido lleva varios productos y un producto se vende en muchos pedidos. La resolvemos con `detalle_pedido` (entidad asociativa) que también guarda `cantidad`, `precio_unitario` y `subtotal` (precio congelado al momento de la venta — R4).
- **¿Por qué la FK de producto a categoría es NOT NULL?** Participación total (R1): todo producto pertenece a una categoría. La participación parcial de categoría la permite crear categorías vacías.
- **¿En qué forma normal está el esquema?** En BCNF. La clave de la planilla era `(pedido_id, nombre_producto)`; separamos `fecha/cliente/forma_pago` (dependen de `pedido_id`) y `categoria` (depende del producto), y el único determinante que quedó en cada tabla es su clave candidata.

### Integridad y transacciones (objs 7-8)
- **¿Cómo implementás el borrado lógico?** Columna `activo` + trigger `BEFORE DELETE` que lanza excepción. Solo se da de baja con `UPDATE activo = FALSE`. Demostré que el catálogo pasa de 50.000 a 49.999 y el histórico de ventas del producto sigue intacto.
- **¿Qué anomalías de aislamiento reproduciste?** Lectura no repetible (10→50 en READ COMMITTED, desaparece con REPEATABLE READ) y lectura fantasma (desaparece con SERIALIZABLE). Mido el bloqueo `FOR UPDATE` de la sesión B en ~3,4 s.
- **¿Rompiste algo con los triggers?** El trigger de stock valida antes de insertar y descuenta; el de subtotal valida `cantidad × precio_unitario`.

### Optimización (objs 5-6, informes)
- **¿Qué optimizaste y cuánto ganaste?** (decir 2-3 números de la tabla de abajo.)
- **¿Por qué descartaste un índice de la IA?** `idx_producto_categoria` era redundante con `idx_producto_categoria_activo` de la Semana 1; duplicaba el costo de escritura sin cambiar el plan.
- **¿Qué es la vista materializada y cuándo conviene?** Precalcula la facturación por categoría/mes; la consulta cae de ~2,4 s a ~15 ms. Se refresca con `REFRESH CONCURRENTLY` (mensual, corte contable); entre refrescos queda congelada.

### IA (DUIA)
- **¿Qué rol tuvo la IA?** Generó SQL, specs, interpretación de planes. **¿Qué descartaste?** índices redundantes y una reescritura sin impacto medible. La IA cometió 3 imprecisiones al leer un plan (Hash Join ≠ Nested Loop, build/probe, cost vs tiempo) que corregimos con el motor.
- **¿Kiro?** No está instalado en la máquina: usé la plantilla de Kiro a mano y OpenCode; lo dejé constado en el DUIA.

## Tabla de números para citar en defensa

| Métrica | Valor |
|---|---|
| Base de datos | 50.000 productos · 200.000 pedidos · 600.000 líneas |
| C1 facturación (TP4) | 4387 → 2052 ms (**2,1×**) |
| C2 ranking (TP4) | 754 → 751 ms (sin mejora, índice descartado) |
| Índice catálogo por nombre | 20 → 8,4 ms (Seq→Bitmap, parcial `WHERE activo`) |
| Índice cliente por apellido | 15,9 → 0,9 ms (~18×) |
| Pedidos tarjeta por mes | 78,4 → 6,8 ms (sin remoción de filas) |
| Vista materializada | 2447 → ~15 ms (**~163×**) |
| Costo escritura (300 INSERT) | 47,5 → 151,6 ms (+3,2×, aceptado) |
| Concurrencia | B bloqueada ~3,4 s en `FOR UPDATE` |
| Equivalencias SQL | EXCEPT = 0 filas (RANK vs correlacionada; correlacionada vs GROUP BY) |

## Diagramas
Los diagramas de modelo ER están en `01_mer_relacional.md` (sección 1) y en el PDF oficial del TP1 entregado por cátedra.