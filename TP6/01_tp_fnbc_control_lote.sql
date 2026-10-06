-- ============================================================================
-- TP6 - Unidad 4 | Parte 1 - FNBC sobre ControlLoteAlmacen
-- Food Store - extension mayorista (control de calidad de lotes)
--
-- Requiere: tablas maestras lote, deposito y usuario ya creadas y pobladas
--           (ver 00_setup_ambiente.sql del mismo TP).
--
-- Contenido:
--   1. Esquema original control_lote_almacen (el del enunciado) + instancia
--   2. Descomposicion sin perdida en dos tablas en FNBC
--   3. Vista de compatibilidad que reconstruye la relacion original
--   4. Migracion de la instancia y verificacion de equivalencia (EXCEPT = 0)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Esquema original (redactado en el enunciado, con FK reales)
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS control_lote_almacen CASCADE;

CREATE TABLE control_lote_almacen (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);

-- Instancia de ejemplo del enunciado
INSERT INTO control_lote_almacen VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

-- ----------------------------------------------------------------------------
-- 2. Descomposicion sin perdida (algoritmo de la clase)
--    R(LoteID, DepositoID, ResponsableControlID)
--    DFs:  LoteID DepositoID -> ResponsableControlID        (trivial de la PK)
--          ResponsableControlID -> DepositoID               (dato maestro)
--    La DF violatoria de FNBC es: ResponsableControlID -> DepositoID
--    (su determinante no es superclave). Se descompone en:
--      R1(LoteID, ResponsableControlID)                clave (LoteID, RC)
--      R2(ResponsableControlID, DepositoID)            clave ResponsableControlID
--    Atributo comun: ResponsableControlID, superclave de R2  => union sin perdida.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS lote_responsable CASCADE;
DROP TABLE IF EXISTS responsable_deposito CASCADE;

-- R1: por cada lote, el responsable que controlo/controla su control
CREATE TABLE lote_responsable (
    lote_id                 BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, responsable_control_id)
);

-- R2: dato maestro de dotacion - cada responsable pertenece a un unico deposito
CREATE TABLE responsable_deposito (
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario(id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito(id),
    PRIMARY KEY (responsable_control_id)
);

-- ----------------------------------------------------------------------------
-- 3. Vista de compatibilidad (reunion natural sobre ResponsableControlID)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_control_lote_almacen AS
SELECT lr.lote_id,
       rd.deposito_id,
       lr.responsable_control_id
FROM lote_responsable lr
JOIN responsable_deposito rd USING (responsable_control_id);

-- ----------------------------------------------------------------------------
-- 4. Migracion de la instancia hacia las tablas descompuestas
--    y verificacion de equivalencia en ambos sentidos (EXCEPT debe dar 0 filas)
-- ----------------------------------------------------------------------------
INSERT INTO lote_responsable (lote_id, responsable_control_id)
SELECT DISTINCT lote_id, responsable_control_id FROM control_lote_almacen;

INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id FROM control_lote_almacen;

-- Verificacion 1: nada en la vista que no este en la relacion original
SELECT '1) en vista y NO en original' AS check,
       lote_id, deposito_id, responsable_control_id
FROM v_control_lote_almacen
EXCEPT
SELECT '1) en vista y NO en original', lote_id, deposito_id, responsable_control_id
FROM control_lote_almacen;

-- Verificacion 2: nada en la relacion original que no este en la vista
SELECT '2) en original y NO en vista' AS check,
       lote_id, deposito_id, responsable_control_id
FROM control_lote_almacen
EXCEPT
SELECT '2) en original y NO en vista', lote_id, deposito_id, responsable_control_id
FROM v_control_lote_almacen;