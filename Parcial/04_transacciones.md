# Objetivo 8 — Transacciones: atomicidad, aislamientos y concurrencia

Evidencia: `transacciones_prueba.sql` (escenario reproducible) + informe completo en `informe_concurrencia.md` (raíz) + `defensa_oral.md` (sección concurrencia).
Protocolo de la cátedra: `protocolo_seguridad.md` (copia → transacción → respaldo; todo script de escritura corre primero en BEGIN/ROLLBACK).

## 1. Atomicidad y control (COMMIT / ROLLBACK)

- **Protocolo aplicado a todos los scripts:** cada DML/DLL primero corre dentro de `BEGIN ... ROLLBACK` y solo se confirma al verificar el efecto (protocolo_seguridad.md). Ejemplos con `SAVEPOINT` en tests de restricciones (TP2, `test_restricciones.sql`).
- La antítesis que protege el protocolo: `fn_impedir_delete_logico` levanta `RAISE EXCEPTION` que aborta la transacción entera → sin 0 filas parciales (atomicidad de statement y de transacción).

## 2. Niveles de aislamiento reproducidos en el motor

Todas con **dos sesiones concurrentes** sobre `food_store_tp3`, verificadas con salida real (no simulada).

### Escenario 1 — Lectura no repetible (READ COMMITTED)
- A: `BEGIN; SET TRANSACTION ISOLATION LEVEL READ COMMITTED; SELECT stock ...` → **10**.
- B: `UPDATE ... SET stock = 50; COMMIT`.
- A: mismo `SELECT` → **50**. ROLLBACK.
- **Conclusión:** con READ COMMITTED cada lectura ve el último COMMIT; entre las dos lecturas de A ocurrió el commit de B → anomalía.
- Con **REPEATABLE READ**: el snapshot se toma al inicio → la segunda lectura sigue viendo **10**. La anomalía desaparece (verificado).

### Escenario 2 — Lectura fantasma (READ COMMITTED)
- A: `BEGIN;` + `SELECT count(*)` (READ COMMITTED).
- B: `INSERT` de un producto activo nuevo; `COMMIT`.
- A: segundo `count(*)` → **incluye** la fila nueva (fantasma).
- Con **SERIALIZABLE**: el segundo COUNT no ve la fila insertada (verificado).

### Escenario 3 — Control de concurrencia con `SELECT ... FOR UPDATE`
- A: `BEGIN; SELECT ... FOR UPDATE` sobre una fila (lock exclusivo, sin COMMIT).
- B: `SELECT ... FOR UPDATE` sobre la misma fila → **se bloquea esperando**.
- A: `ROLLBACK` → B se desbloquea y devuelve la fila.
- **Medición real:** B tardó **~3,4 s** (espera por el lock, no es error).
- El nivel de aislamiento no cambia este comportamiento (el lock exclusivo ocurre en READ COMMITTED y REPEATABLE READ por igual).

### Escenario 4 — Deadlock (documentado en defensa_oral.md)
- A y B toman locks en órdenes opuestos (A: fila X→Y; B: fila Y→X). El motor detecta el ciclo y aborta **una** transacción con `ERROR: deadlock detected`. La otra completa.
- Lección: el detector de deadlocks de PostgreSQL rompe el ciclo automáticamente; la app debe reintentar la transacción abortada.

## 3. Resultados y ubicación de evidencia

| Tema | Resultado | Archivo |
|---|---|---|
| Lectura no repetible | 10→50 (READ COMMITTED); 10→10 (REPEATABLE READ) | `informe_concurrencia.md` §1 |
| Lectura fantasma | count cambia (READ COMMITTED); estable (SERIALIZABLE) | `informe_concurrencia.md` §2 |
| FOR UPDATE / bloqueo | B esperó ~3,4 s; se liberó con ROLLBACK de A | `informe_concurrencia.md` §3 |
| Deadlock | aborto automático de una transacción | `defensa_oral.md` |

## 4. Script de demostración rápida (`transacciones_prueba.sql`)

Las 3 anomalías + FOR UPDATE en un solo archivo, pensado para correr con dos consolas `psql` A/B. El script deja el esquema intacto (todas las transacciones cierran con ROLLBACK).