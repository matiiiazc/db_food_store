# TP3 — Parte 3: Lectura crítica de un plan interpretado por IA

## Plan real utilizado

Se entrega a la IA **solo el texto del plan** (sin contexto adicional), obtenido con `EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)` sobre la consulta optimizada de la Parte 2 (resumen de ventas por producto):

```
Limit (actual time=260.105..260.110 rows=20 loops=1)
  ->  Sort (actual time=260.103..260.106 rows=20 loops=1)
        Sort Key: (sum(subtotal)) DESC
        Sort Method: top-N heapsort  Memory: 27kB
        ->  Hash Join (actual time=23.039..245.921 rows=50000 loops=1)
              Hash Cond: (detalle_pedido.producto_id = pr.id)
              ->  GroupAggregate (actual time=1.091..201.239 rows=50000 loops=1)
                    Group Key: detalle_pedido.producto_id
                    ->  Index Only Scan using idx_detalle_producto_cover
                          on detalle_pedido (actual time=0.440..86.989 rows=600000 loops=1)
                          Heap Fetches: 0
              ->  Hash (actual time=21.773..21.774 rows=50000 loops=1)
                    ->  Seq Scan on producto pr (actual time=0.045..10.312 rows=50000 loops=1)
Planning Time: 24.359 ms
Execution Time: 262.217 ms
```

## Explicación de la IA (respuesta generada)

> "La consulta usa un Index Only Scan sobre `detalle_pedido` que es muy rápido porque no lee el disco ni toca las tablas: lee todo el índice de una vez. Después agrupa por producto y une con la tabla `producto`. El Hash Join es la parte más cara de toda la consulta. El costo estimado total es de 29894 y la ejecución tarda cerca de 290 milisegundos. Como hay un LIMIT 20, el ordenamiento es extremadamente barato: solo hay que ordenar las 20 filas finales."

## Tabla de lectura crítica — frase por frase

| Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real |
|---|---|---|
| "Index Only Scan ... no lee el disco ni toca las tablas: lee todo el índice de una vez" | **Parcialmente incorrecta** | Es correcto que es Index Only Scan, y `Heap Fetches: 0` confirma que no toca el heap de la tabla. Pero "no lee el disco" es falso: `Buffers: shared hit=2959` indica que si bien esta corrida estuvo cacheada en el buffer pool, un índice se lee por bloques igual que una tabla (físicamente también se lee de disco cuando no está en caché). Además **lee las 600.000 entradas del índice**, no "todo de una vez": `rows=600000` y `Index Searches: 1`. No es "una lectura" sino un barrido completo del índice (600.000 filas). |
| "El Hash Join es la parte más cara de toda la consulta" | **Incorrecta** | El plan real muestra que el nodo más caro es el **GroupAggregate** (`actual time=1.091..201.239`, o sea ~200 ms), que supera ampliamente al Hash Join (`actual time=23.039..245.921` acumulado pero empieza a los 23 ms; el agregado insume la mayor parte del tiempo). El `Index Only Scan` a su vez consume ~87 ms. La afirmación atribuye el costo al nodo equivocado. |
| "El costo estimado total es de 29894" | **Incorrecta / imprecisa** | El plan fue generado con `COSTS OFF` y **no muestra ningún costo estimado**. El número 29894 proviene del plan de la Parte 2 (que sí tenía costos), no de este plan. La IA rellenó con un dato de otra corrida y lo presentó como parte de este plan. Además confunde la escala: 29894 es el **costo estimado** (en unidades PostgreSQL, no milisegundos) y de ninguna manera debe leerse como tiempo. Es el error clásico de *"confundir cost con milisegundos"*. |
| "la ejecución tarda cerca de 290 milisegundos" | **Parcialmente correcta pero confusa** | `Execution Time: 262.217 ms`. Cerca. Pero el dato confiable en un plan con ANALYZE es el `Execution Time` (262 ms), no el `actual time` de un nodo suelto. La IA mezcla 290 (que no aparece en el plan) en lugar de citar 262 ms. |
| "el ordenamiento es extremadamente barato: solo hay que ordenar las 20 filas finales" | **Incorrecta** | El `Sort` ordena las **50.000 filas agregadas** (`rows=50000`), no 20. Lo que sí es barato es el *método de ordenamiento*: `top-N heapsort` con `Memory: 27kB`. El `LIMIT 20` hace que PostgreSQL use un *top-N heapsort* (mantiene solo los top-20 en memoria) en vez de un sort completo, y por eso usa solo 27 kB. La IA confundió "LIMIT hace el sort más barato" (cierto, por el top-N heapsort) con "solo se ordenan 20 filas" (falso; se agregan 50.000 grupos y se hace top-N sobre ellos). |
| (implícito) "el Index Only Scan no toca las tablas" | **Correcto** | `Heap Fetches: 0` y `Index Searches: 1` confirman el access path por índice de cobertura sin visitar el heap. |

## Hallazgos principales de la lectura crítica

1. **Confunde costo estimado con milisegundos** (regla de oro detectada): cita "costo 29894" y "290 ms" como si fueran intercambiables. En PostgreSQL el cost es una heurística adimensional; los milisegundos los da solo `ANALYZE`. Un plan sin `ANALYZE` no tiene tiempos reales.
2. **Atribuye el costo al nodo equivocado**: dice que el Hash Join es "lo más caro", cuando el plan muestra que el **GroupAggregate** (y su entrada por barrido del índice de 600.000 filas) domina el tiempo.
3. **Malinterpreta el LIMIT**: el sort captura 50.000 filas; el límite solo habilita el método *top-N heapsort* (27 kB). No "ordena 20 filas".
4. **Rellena datos de otra corrida**: el "29894" no está en este plan (`COSTS OFF`); fue recordado de otro plan. Patrón de IA a vigilar: alucinar números plausibles.
5. La única afirmación correctamente hecha es que el Index Only Scan evita tocar la tabla (heap), confirmado por `Heap Fetches: 0`.

## Conclusión

La explicación de la IA, aunque suena técnica y convincente, contiene **cuatro imprecisiones reales** (costo vs. milisegundos, nodo más caro, interpretación del LIMIT, y dato inventado/recordado de otra corrida). Esto confirma el riesgo que la cátedra busca entrenar: **un plan de EXPLAIN ANALYZE solo se puede dar por explicado cuando se contrasta cada afirmación contra la evidencia del plan real**, no cuando la respuesta es fluida.
