# Defensa Oral — TP3 Optimización de Consultas

> Guía para defender cada script e índice de la entrega, siguiendo la lógica: **medir antes → proponer con la IA → aplicar lo justificable → medir después → decidir con datos**.

## 1. Protocolo de seguridad (por qué se hizo así)

- **Copia**: la base `food_store_tp3` se creó desde el esquema (`schema.sql` + `restricciones.sql`), separada de `plantilla_base`. Nunca se tocó la base del proyecto.
- **Respaldo**: antes de optimizar se tomó `pg_dump -Fc food_store_tp3_respaldo.dump`.
- **Transacción**: la carga masiva corre dentro de `BEGIN...COMMIT`.

## 2. Parte 1 — Carga masiva

¿Qué cambió y por qué? El script:
- Carga **50.000 productos** (precio aleatorio 500–5000, stock 0–200) repartidos entre las 4 categorías, **20.000 clientes**, **200.000 pedidos** y **600.000 líneas de detalle** (3 por pedido, con `subtotal = cantidad × precio_unitario`).
- Usa `generate_series`, sin PL/pgSQL (lo pedía la spec), y respeta UNIQUE/CHECK/FK.
- **Punto clave a defender**: los triggers del TP2 (`fn_descontar_stock`, `fn_verificar_subtotal`, `fn_impedir_delete_logico`) se desactivaron durante el seed con `ALTER TABLE ... DISABLE TRIGGER ALL` y se reactivaron al final. **Por qué está bien**: la carga es un seed, no una venta real; dejar los triggers activos habría hecho el bulk insert lentísimo (un UPDATE+SELECT por fila) y habría dejado los stocks en negativo. Es una operación reversible y documentada en la DUIA. Se verificó que quedaron en estado `O` (habilitados) al terminar.

## 3. Parte 2 — Optimización medida (la más importante para defender)

### Consulta 1 (resumen de ventas por producto) — mejora estrella
- **Antes**: `Parallel Seq Scan on detalle_pedido` + `HashAggregate` que reventaba a disco (`Batches: 5`, `Disk Usage ~7MB`) → 994 ms.
- **Cambio**: reescribir para agrupar por `producto_id` (no por `pr.nombre`) y crear el índice de cobertura `idx_detalle_producto_cover (producto_id) INCLUDE (cantidad, subtotal)`.
- **Después**: `Index Only Scan ... Heap Fetches: 0` + `GroupAggregate` sin spool → 290 ms.
- **Por qué funciona (frase de defensa)**: *"Agrupar por la columna indexada permite que el índice de cobertura responda la suma sin leer el heap; el join con `producto` (50.000 filas, baratas) se hace al final para traer el nombre."* La versión original agrupaba por el nombre que viene de `producto`, y eso obligaba al plan a hacer el join primero y romper la cobertura del índice.
- **Evidencia**: cost 60128 → 29894; tiempo 994 → 290 ms; Heap Fetches 0.

### Consulta 2 (facturación por rango de fechas)
- **Antes**: `Seq Scan on pedido` con `Rows Removed by Filter: 122160` (recorre 200.000 filas para quedarse con 77.840 del año).
- **Cambio**: `CREATE INDEX ON pedido (fecha)`.
- **Después**: `Bitmap Index Scan on idx_pedido_fecha` → cost 13805 → 13656, y el plan cambió **exactamente el nodo predicho**.
- **Pero el tiempo no mejoró** (114 → 124 ms). **Por qué (honestidad profesional)**: el rango `2025–2026` devuelve el 40% de la tabla; el índice evita recorrer el log de la tabla pero igual hay que leer ~77.000 bloques del heap. Con un rango chico (un mes) la ganancia sería clara. **Decisión**: el índice se mantiene porque es el acceso correcto para consultas puntuales; la limitación es del rango de test, no del índice.
- **Frase de defensa**: *"El índice cambió el plan (Seq Scan → Bitmap Index Scan) y bajó el cost estimado, pero el tiempo real no bajó porque el rango filtra el 40% de la tabla; a esta selectividad el índice no brilla, aunque es el acceso correcto para rangos chicos."*

### Consulta 3 (total vendido por mes) — propuesta descartada con registro
- **Antes/Después**: el plan quedó igual — `Seq Scan detalle` + Hash Join + **sort a disco de 27.136 kB**.
- **Por qué el índice por fecha no la ayudó**: el `Group Key` es `date_trunc('month', fecha)` y el join es por `pedido_id`, no por `fecha`. El índice en `fecha` no participa del orden de la agregación.
- **Decisión**: no hay índice que evite ordenar 600.000 filas por mes con `count(distinct pedido_id) + sum`. Se documenta qué se esperaba, qué pasó y por qué. **Esto es exactamente lo que pide el criterio de aceptación**: no aplicar a ciegas, documentar hasta lo que no mejora.

## 4. Parte 3 — Lectura crítica del plan interpretado por IA

Se le dio a la IA un plan **sin costos** (COSTS OFF) y se le pidió explicarlo nodo por nodo. La explicación tenía **4 imprecisiones reales** que hay que saber señalar:
1. **Confundió cost con milisegundos**: citó "cost 29894" y "290 ms" como intercambiables. En PostgreSQL el cost es una heurística adimensional; los ms solo los da `ANALYZE`.
2. **Atribuyó el costo al nodo equivocado**: dijo "el Hash Join es lo más caro" cuando el plan muestra que lo domina el `GroupAggregate` (~200 ms vs ~23 ms del join).
3. **Malinterpretó el LIMIT**: dijo "ordena 20 filas"; en realidad agrega 50.000 grupos y el `LIMIT` solo habilita un *top-N heapsort* (27 kB).
4. **Rellenó un dato de otra corrida**: el "29894" no está en un plan COSTS OFF; la IA lo recordó de otro plan.

La única afirmación correcta fue que el Index Only Scan no toca la tabla (`Heap Fetches: 0`).

## 5. Parte 4 — Equivalencia verificada

- **Spec 1** (agregación): LEFT JOIN con condición en el ON vs. subconsulta escalar → EXCEPT da 0 filas en ambas direcciones → equivalentes. Poder explicar por qué la condición de `activo` va en el JOIN (si fuera en el WHERE, el LEFT JOIN se volvería INNER y perdería categorías con 0 productos).
- **Spec 2** (subconsulta): HAVING-subconsulta vs. CTE+join con CROSS JOIN promedios → EXCEPT da 0 filas → equivalentes.
- **Frase de defensa**: *"No verifiqué por 'corre sin error', verifiqué formalmente con EXCEPT en las dos direcciones: si ambas versiones devuelven 0 filas de diferencia, son equivalentes."*

## 6. DUIA y cierre

- Cada uso de la IA está declarado con prompt/resumen y la decisión (aceptado/descartado) con su fundamento: ver `DUIA_tp3.md`.
- Mensaje central a transmitir: **el motor manda**. Dos de las tres propuestas de la IA no mejoraron el tiempo real (una por rango poco selectivo, otra por causa equivocada); solo la reescritura + índice medidos confirmaron la mejora. Sin `EXPLAIN ANALYZE` no se habría sabido.
