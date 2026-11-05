# Bitácora de uso de IA — TP8 (Food Store)

Herramienta: OpenCode (asistente), usado para generar scripts a partir de las tareas/spec y para la revisión crítica (consigna 3.c). Todo lo generado se leyó y se probó antes de ejecutarlo/entregarlo.

## Entrada 1 — Esquema SQLite y tipos
- **Pedido a la IA:** generar `schema_sqlite.sql` con las 4 tablas `STRICT`, `PRAGMA foreign_keys=ON`, centavos enteros y CHECKs (forma de pago, estados, flags 0/1, cantidad>0).
- **Aceptado:** la estructura de tablas, FKs (item->borrador y item->producto_cache, cola->borrador) y los CHECKs, alineados al modelo real (forma_pago_enum = EFECTIVO/TARJETA/TRANSFERENCIA) y a la regla de centavos.
- **Descartado/modificado:** una primera propuesta usaba `precio REAL`; se descartó por riesgo de punto flotante y se reemplazó por `precio_centavos INTEGER` (consigna). Se verificó con la ejecución de `pruebas_sqlite.sql`/evidencia (C7a cantidad 0 y FK fallan; sin filas nuevas).

## Entrada 2 — Caso C7 (producto inexistente)
- **Pedido a la IA:** demostrar C7b (producto inexistente) insertando un `producto_id` que no exista.
- **Aceptado:** la estrategia de capturar el error de `FOREIGN KEY` y comprobar que el conteo de ítems no cambia.
- **Descartado/corregido:** el ejemplo usó `producto_id=9999`; al cargar la instantánea real (`producto_cache` con 50.000 filas) el id 9999 **sí existía**, por lo que el INSERT no falló. Se descartó ese dato de prueba y se corrigió a `9999999` (verificado inexistente: `existe 9999999? 0`) obteniendo `FOREIGN KEY constraint failed` y 0 filas nuevas. Evidencia: `evidencia_pruebas_sqlite.txt` y `fix_c7b.py`.

## Entrada 3 — Semáforo y recarga de caché
- **Pedido a la IA:** implementar `semaforo.sql` (solo PENDIENTE -> RECHAZADO/CONFLICTO/SIMULADO_APROBADO) y la recarga de `producto_cache` desde la instantánea para los casos C2–C6.
- **Aceptado:** la consulta de semáforo con `LEFT JOIN snapshot_servidor`, prioridad rojo>amarillo>verde (`SUM(CASE...)`), `UPDATE ... FROM` y filtro `WHERE c.estado='PENDIENTE'` (idempotente). Se probó: C2->CONFLICTO luego SIMULADO_APROBADO, C3/C4->RECHAZADO, C5->SIMULADO_APROBADO, C6 PK duplicada + sin re-evaluación (`evidencia_casos.txt`).
- **Descartado/corregido:** una recarga que hacía `DELETE FROM producto_cache` con FKs activas falló (`FOREIGN KEY constraint failed`) porque `item_borrador` referencia al caché; también un `ON CONFLICT DO UPDATE` directo dio un error de sintaxis en el contexto de ejecución. Se descartó ese enfoque y se adoptó recarga con `PRAGMA foreign_keys=OFF` fuera de transacción + reinsertar los mismos ids + `ON`, preservando las referencias. Probado en `run_casos.py`.

## Entrada 4 — Code review (consigna 3.c)
- **Pedido a la IA:** revisar scripts de la cursada y proponer hallazgos.
- **Aceptado:** hallar que `fn_autenticar` (U5, `SECURITY DEFINER`) no fija `search_path` (verificado: `proconfig` NULL en `pg_proc`) y que `sp_registrar_pedido` (TP3) repite la subconsulta de precio y deriva producto inexistente en `NULL`->violación NOT NULL (verificado con `CALL` en transacción + `ROLLBACK`, sin cambios persistidos).
- **Descartado con fundamento:** la sugerencia de eliminar `idx_pedido_fecha` por considerarlo redundante frente a `idx_pedido_forma_fecha (forma_pago,fecha)`. Se verificó que ambos coexisten (`pg_indexes`), pero se **descartó** el borrado: el índice compuesto tiene `forma_pago` como columna líder y no sirve igual a filtros que acotan solo por rango de `fecha` (consultas tipo TP3 C2/C3), por lo que `idx_pedido_fecha` sigue siendo útil. Decisión: mantener ambos. (Ver tabla 3.c del informe.)