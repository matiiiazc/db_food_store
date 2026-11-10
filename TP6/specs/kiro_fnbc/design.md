# design.md — TP6 Food Store (migración FNBC transaccional reversible)

## 1. Contexto

`01_tp_fnbc_control_lote.sql` demuestra la descomposición sin pérdida de `control_lote_almacen(lote_id, deposito_id, responsable_control_id)` hasta FNBC:

- `R1 lote_responsable(lote_id, responsable_control_id)` — PK `(lote_id, responsable_control_id)`.
- `R2 responsable_deposito(responsable_control_id, deposito_id)` — PK `(responsable_control_id)`.
- DF violatoria de FNBC en el original: `ResponsableControlID → DepositoID` (su determinante no es superclave).
- Vista de compatibilidad `v_control_lote_almacen` = reunión natural de R1 ⋈ R2 sobre `responsable_control_id` (superclave de R2 ⇒ unión sin pérdida).

Este documento especifica el **envoltorio transaccional** de la migración y su **plan de reversión**, exigidos por el objetivo oficial de U4 ("migración de datos sin pérdida, ejecutada dentro de transacciones reversibles y especificada en Kiro, con plan de reversión obligatorio"). El script que lo implementa es `04_migracion_transaccional_reversible.sql`.

## 2. Estrategia transaccional

PostgreSQL ejecuta el DDL dentro de transacciones. Toda la migración (drop de objetos descompuestos, `CREATE TABLE` de R1/R2, `CREATE VIEW`, `INSERT ... SELECT` de migración y verificación) corre entre `BEGIN` y `COMMIT|ROLLBACK`:

- **Corrida A — COMMIT verificado:** recrea el esquema descompuesto, migra leyendo `control_lote_almacen`, verifica la equivalencia bidireccional **dentro de la transacción** (bloque `DO`, REQ-02) y recién entonces hace `COMMIT`. Si la verificación falla, `RAISE EXCEPTION` aborta y el `COMMIT` nunca se ejecuta.
- **Corrida B — ROLLBACK demostrado:** replica la migración pero desde una copia **temporal** del origen contaminada con una fila que viola la DF (`(501,31,801)`: el responsable 801 pasaría a tener dos depósitos). La PK de `responsable_deposito` rechaza la segunda fila del responsable ⇒ la transacción aborta a mitad de migración ⇒ `ROLLBACK` restaura el estado previo exacto (tablas, vista y filas), demostrando REQ-03. La tabla temporal muere con la transacción y el origen real nunca se toca.

## 3. Verificación dentro de la transacción (REQ-01/02)

Bloque `DO` anónimo que cuenta ambos `EXCEPT` (vista vs. original y original vs. vista):

```sql
DO $$
DECLARE solo_en_vista int; solo_en_original int; filas int;
BEGIN
  SELECT count(*) INTO solo_en_vista   FROM (SELECT ... FROM v_control_lote_almacen EXCEPT SELECT ... FROM control_lote_almacen) a;
  SELECT count(*) INTO solo_en_original FROM (SELECT ... FROM control_lote_almacen EXCEPT SELECT ... FROM v_control_lote_almacen) b;
  IF solo_en_vista <> 0 OR solo_en_original <> 0 THEN
    RAISE EXCEPTION 'MIGRACION INCONSISTENTE: solo_en_vista=%, solo_en_original=% (la transaccion se revertira)', solo_en_vista, solo_en_original;
  END IF;
END $$;
```

El `COMMIT` es la última sentencia de la corrida: solo se alcanza si la verificación pasó.

## 4. Inyección de fallo (prueba de reversibilidad, REQ-03/05)

Dentro de la transacción de la Corrida B:

1. `CREATE TEMP TABLE src_anomala AS SELECT * FROM control_lote_almacen;` (copia temporal, sin FKs).
2. `INSERT INTO src_anomala VALUES (501, 31, 801);` — ids reales del modelo; la PK `(lote_id, deposito_id)` está libre; el contenido viola la DF `ResponsableControlID → DepositoID` porque 801 ya tiene el depósito 30.
3. La migración desde `src_anomala` inserta bien en `lote_responsable` (los pares lote/responsable son únicos) pero **falla** en `responsable_deposito`: `duplicate key value violates unique constraint "responsable_deposito_pkey"` (801 ya fue insertado con el depósito 30 y reaparece con el 31).
4. La transacción queda abortada; `ROLLBACK` deshace también los `DROP/CREATE` previos.
5. Verificación post-`ROLLBACK`: las tres tablas y la vista tienen exactamente las filas y el esquema de antes de la corrida (la sección final del script lo comprueba).

## 5. Guarda de seguridad

El script abre con un bloque `DO` que **bloquea su ejecución sobre la base protegida** (`food_store_tp3`) y sobre bases de sistema: solo corre en copias de prueba (p. ej. `food_store_tp3_u4_fnbc_<ts>` restaurada de un dump verificado).

## 6. Plan de reversión obligatorio (REQ-06)

**Estado inicial:** migración confirmada (Corrida A): R1/R2 pobladas, vista en uso, `control_lote_almacen` intacto (REQ-04: la migración nunca lo borra ni actualiza — es solo lectura).

**Pasos para revertir al esquema original:**

```sql
BEGIN;
-- (1) Congelar o eliminar los objetos derivados. Opción conservadora (auditoría):
ALTER VIEW v_control_lote_almacen RENAME TO v_control_lote_almacen_deprecada;
ALTER TABLE lote_responsable    RENAME TO lote_responsable_deprecada;
ALTER TABLE responsable_deposito RENAME TO responsable_deposito_deprecada;
-- Opción limpia (los datos derivados se descartan; el original los contiene):
-- DROP VIEW IF EXISTS v_control_lote_almacen;
-- DROP TABLE IF EXISTS lote_responsable, responsable_deposito;
-- (2) Verificar que el original quedó intacto:
-- SELECT * FROM control_lote_almacen ORDER BY 1,2;   -- debe devolver la instancia completa
COMMIT;
```

**Por qué no hay pérdida:** la migración copia (`INSERT ... SELECT`) desde `control_lote_almacen` sin borrarlo ni modificarlo; el original sigue conteniendo la totalidad de la instancia migrada. Revertir es eliminar objetos derivados, no reconstruir datos.

**Reversión a mitad de migración (fallo sin commit):** simplemente `ROLLBACK` — restauración total incluido el DDL (REQ-03, demostrado en la Corrida B).

**Plan de reversión de la desnormalización (Parte 2 del TP6):** `DROP MATERIALIZED VIEW mv_top_categorias_dia` elimina el objeto redundante sin tocar las tablas fuente (ver `03_informe_tp6.md` §Parte 2b).

## 7. Matriz de pruebas

| REQ | Corrida / sección | Resultado esperado | Dónde se evidencia |
|---|---|---|---|
| REQ-01 | A: bloque `DO` | `solo_en_vista=0`, `solo_en_original=0` | salida de `psql -f 04_...` |
| REQ-02 | A: estructura | `COMMIT` solo tras verificación OK | salida de `psql -f 04_...` |
| REQ-03 | B: `ROLLBACK` + verificación final | tablas/vista/filas idénticas al estado previo | sección "post-rollback" del script |
| REQ-04 | A y B: conteo del origen | 3 filas `(501,30,801),(502,30,801),(503,31,802)` antes y después | sección "estado del origen" |
| REQ-05 | B: INSERT en `responsable_deposito` | `duplicate key ... responsable_deposito_pkey` | error capturado en la salida |
| REQ-06 | Documentación | pasos de reversión ejecutables | este documento §6 |

**Base de prueba:** copia restaurada de un dump verificado (nunca `food_store_tp3`). Guarda de seguridad al inicio del script (§5).
