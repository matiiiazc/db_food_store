-- ============================================================================
-- TP6 - Unidad 4 | Migracion transaccional reversible de la descomposicion
--            FNBC de control_lote_almacen
-- Food Store - complemento de 01_tp_fnbc_control_lote.sql
--
-- Objetivo oficial U4 (2a entrega): "Migracion de datos sin perdida,
-- ejecutada dentro de transacciones reversibles ... con plan de reversion
-- obligatorio". Especificada en specs/kiro_fnbc/{requirements,design}.md.
--
-- Contenido:
--   0. Guarda: bloquea la ejecucion sobre la base protegida food_store_tp3
--   A. CORRIDA A (COMMIT verificado): recrea R1/R2 + vista, migra leyendo
--      control_lote_almacen (SOLO LECTURA) y verifica EXCEPT=0 en ambos
--      sentidos DENTRO de la transaccion; el COMMIT es la ultima sentencia.
--   B. CORRIDA B (ROLLBACK demostrado): repite la migracion desde una copia
--      TEMPORAL del origen contaminada con una fila que viola la DF
--      ResponsableControlID -> DepositoID ((501,31,801): responsable 801
--      con dos depositos). La PK de responsable_deposito rechaza la fila,
--      la transaccion aborta a mitad de migracion y el ROLLBACK restaura
--      el estado previo exacto (incluido el DDL, transaccional en PG).
--   C. Verificacion post-rollback: tablas/vista/filas identicas al estado
--      previo y control_lote_almacen sin cambios (solo lectura efectiva).
--
-- Plan de reversion obligatorio (si ya hubo COMMIT): specs/kiro_fnbc/design.md 6.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. GUARDA DE SEGURIDAD: nunca sobre la base protegida ni bases de sistema
-- ----------------------------------------------------------------------------
DO $$
DECLARE db text := current_database();
BEGIN
  IF db = 'food_store_tp3' THEN
    RAISE EXCEPTION 'BLOQUEADO: % es la base original protegida. Ejecutar solo en una copia de prueba.', db;
  END IF;
  IF db IN ('postgres', 'template0', 'template1') THEN
    RAISE EXCEPTION 'BLOQUEADO: % es una base de sistema.', db;
  END IF;
  RAISE NOTICE 'GUARDA OK: base de prueba %', db;
END $$;

\echo '== ESTADO PREVIO (antes de cualquier corrida) =='
SELECT 'control_lote_almacen' AS tabla, count(*) AS filas FROM control_lote_almacen
UNION ALL SELECT 'lote_responsable', count(*) FROM lote_responsable
UNION ALL SELECT 'responsable_deposito', count(*) FROM responsable_deposito
UNION ALL SELECT 'v_control_lote_almacen', count(*) FROM v_control_lote_almacen
ORDER BY 1;
SELECT * FROM control_lote_almacen ORDER BY lote_id, deposito_id;

-- ----------------------------------------------------------------------------
-- A. CORRIDA A: migracion transaccional con verificacion y COMMIT
-- ----------------------------------------------------------------------------
\echo '== CORRIDA A: BEGIN =='
BEGIN;

DROP VIEW IF EXISTS v_control_lote_almacen;
DROP TABLE IF EXISTS lote_responsable CASCADE;
DROP TABLE IF EXISTS responsable_deposito CASCADE;

-- R1: por cada lote, el responsable que controlo su control de calidad
CREATE TABLE lote_responsable (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- R2: dato maestro de dotacion (un responsable pertenece a UN deposito)
CREATE TABLE responsable_deposito (
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id),
    PRIMARY KEY (responsable_control_id)
);

CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT lr.lote_id,
       rd.deposito_id,
       lr.responsable_control_id
FROM lote_responsable lr
JOIN responsable_deposito rd USING (responsable_control_id);

-- Migracion: LEE control_lote_almacen, no lo modifica (REQ-04)
INSERT INTO lote_responsable (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id FROM control_lote_almacen;

INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id FROM control_lote_almacen;

-- Verificacion DENTRO de la transaccion (REQ-01/02): si hay diferencias,
-- RAISE EXCEPTION aborta y el COMMIT de abajo nunca se ejecuta.
DO $$
DECLARE solo_en_vista int; solo_en_original int; filas_vista int;
BEGIN
  SELECT count(*) INTO solo_en_vista FROM (
    SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen
  ) a;
  SELECT count(*) INTO solo_en_original FROM (
    SELECT lote_id, deposito_id, responsable_control_id FROM control_lote_almacen
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id FROM v_control_lote_almacen
  ) b;
  SELECT count(*) INTO filas_vista FROM v_control_lote_almacen;
  IF solo_en_vista <> 0 OR solo_en_original <> 0 THEN
    RAISE EXCEPTION 'MIGRACION INCONSISTENTE: solo_en_vista=%, solo_en_original=% (la transaccion se revertira)', solo_en_vista, solo_en_original;
  END IF;
  RAISE NOTICE 'VERIFICACION OK: EXCEPT=0 en ambos sentidos (filas en vista=%)', filas_vista;
END $$;

\echo '== CORRIDA A: COMMIT (solo se alcanza si la verificacion paso) =='
COMMIT;

SELECT 'lote_responsable' AS tabla_migrada, count(*) AS filas FROM lote_responsable
UNION ALL SELECT 'responsable_deposito', count(*) FROM responsable_deposito
UNION ALL SELECT 'v_control_lote_almacen', count(*) FROM v_control_lote_almacen
ORDER BY 1;

-- ----------------------------------------------------------------------------
-- B. CORRIDA B: inyeccion de fallo (DF violada) => aborto => ROLLBACK
-- ----------------------------------------------------------------------------
\echo '== CORRIDA B: BEGIN =='
BEGIN;

DROP VIEW IF EXISTS v_control_lote_almacen;
DROP TABLE IF EXISTS lote_responsable CASCADE;
DROP TABLE IF EXISTS responsable_deposito CASCADE;

CREATE TABLE lote_responsable (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, responsable_control_id)
);
CREATE TABLE responsable_deposito (
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id),
    PRIMARY KEY (responsable_control_id)
);

-- Copia TEMPORAL del origen contaminada: (501,31,801) viola la DF
-- ResponsableControlID -> DepositoID (801 ya tiene el deposito 30).
-- La tabla temporal vive y muere dentro de esta transaccion; el origen
-- real control_lote_almacen NO se toca.
CREATE TEMP TABLE src_anomala ON COMMIT DROP AS
SELECT * FROM control_lote_almacen;
INSERT INTO src_anomala (lote_id, deposito_id, responsable_control_id)
VALUES (501, 31, 801);

INSERT INTO lote_responsable (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id FROM src_anomala;

-- Este INSERT FALLA por diseño: 801 aparece con deposito 30 y 31 =>
-- duplicate key en responsable_deposito_pkey. La transaccion aborta
-- A MITAD de la migracion (REQ-05) y nada de lo anterior persiste.
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id FROM src_anomala;

\echo '== CORRIDA B: ROLLBACK (la transaccion aborto por la PK de R2) =='
ROLLBACK;

-- ----------------------------------------------------------------------------
-- C. VERIFICACION POST-ROLLBACK: el estado previo quedo restaurado exacto
-- ----------------------------------------------------------------------------
\echo '== ESTADO POSTERIOR (tras ROLLBACK): debe ser identico al previo =='
SELECT 'control_lote_almacen' AS tabla, count(*) AS filas FROM control_lote_almacen
UNION ALL SELECT 'lote_responsable', count(*) FROM lote_responsable
UNION ALL SELECT 'responsable_deposito', count(*) FROM responsable_deposito
UNION ALL SELECT 'v_control_lote_almacen', count(*) FROM v_control_lote_almacen
ORDER BY 1;
SELECT * FROM control_lote_almacen ORDER BY lote_id, deposito_id;
\echo '== FIN: migracion transaccional reversible probada =='
