# requirements.md — TP6 Food Store (migración FNBC transaccional reversible)

Notación EARS. Complementa a `01_tp_fnbc_control_lote.sql` (descomposición FNBC de `control_lote_almacen`): especifica la **migración sin pérdida dentro de transacciones reversibles** y el **plan de reversión obligatorio** (objetivo oficial U4 de la 2ª entrega).

## REQ-01 — Migración sin pérdida (equivalencia bidireccional)
- **WHEN** la instancia de `control_lote_almacen` se migra hacia `lote_responsable` + `responsable_deposito`, **THE SYSTEM SHALL** reconstruir la relación original por reunión natural (`v_control_lote_almacen`) sin tuplas de más ni de menos: ambos `EXCEPT` deben devolver **0 filas**.
- **Se prueba con:** Corrida A de `04_migracion_transaccional_reversible.sql` (bloque `DO` que cuenta ambos `EXCEPT` **dentro de la transacción**, antes del `COMMIT`).

## REQ-02 — Verificación previa al COMMIT
- **WHEN** la verificación de equivalencia (REQ-01) detecta diferencias, **THE SYSTEM SHALL** abortar la transacción con `RAISE EXCEPTION` y **THE SYSTEM SHALL NOT** ejecutar el `COMMIT`.
- **Se prueba con:** la estructura de la Corrida A (el `COMMIT` es la última sentencia; solo se alcanza si el bloque `DO` pasó).

## REQ-03 — Reversibilidad total (incluido el DDL)
- **WHEN** la transacción de migración aborta por cualquier causa (constraint violado, verificación fallida), **THE SYSTEM SHALL** aceptar `ROLLBACK` y restaurar el estado previo exacto —incluidos los cambios de esquema, porque PostgreSQL ejecuta el DDL transaccionalmente— sin dejar migración parcial.
- **Se prueba con:** Corrida B (error intencional) + sección de verificación post-`ROLLBACK` del mismo script (tablas, vista y filas idénticas al estado previo).

## REQ-04 — El esquema original es solo lectura
- **WHEN** la migración se ejecuta, **THE SYSTEM SHALL NOT** modificar `control_lote_almacen` (la fuente de verdad de la reversión): solo lo lee.
- **Se prueba con:** conteo e instancia de `control_lote_almacen` idénticos antes y después de ambas corridas (3 filas: `(501,30,801)`, `(502,30,801)`, `(503,31,802)`).

## REQ-05 — El esquema FNBC hace inrepresentable la violación de la DF
- **WHEN** la instancia de origen contiene un responsable asignado a dos depósitos distintos (viola `ResponsableControlID → DepositoID`), **THE SYSTEM SHALL** rechazar la migración por clave primaria de `responsable_deposito` (la descomposición no tiene dónde guardar el dato inválido).
- **Se prueba con:** Corrida B (fila anómala `(501,31,801)` inyectada en una copia temporal del origen → `duplicate key ... responsable_deposito_pkey`).

## REQ-06 — Plan de reversión obligatorio
- **WHEN** la migración ya fue confirmada (`COMMIT`) y se necesita volver al esquema original, **THE SYSTEM SHALL** seguir el plan de reversión documentado en `design.md` §6 (drop de la vista y las tablas descompuestas; el original nunca fue modificado, por lo que revertir no pierde datos).
- **Se prueba con:** el plan documentado paso a paso en `design.md`; su fundamento es REQ-04 (el original queda como única verdad en todo momento).
