-- ============================================================
-- TPI Food Store - Requisitos adicionales del motor
--  A) Trigger con TABLAS DE TRANSICION (REFERENCING OLD/NEW TABLE)
--  B) Consultas con JSONB
-- Mongo sobre food_store_tp3. La demo termina en ROLLBACK.
-- ============================================================

-- ------------------------------------------------------------
-- A) TRIGGER CON TABLAS DE TRANSICION
--    AFTER ... FOR EACH STATEMENT ... REFERENCING OLD/NEW TABLE
--    Requisito del motor (PostgreSQL 16+ soporta tablas de
--    transicion). Audita una actualizacion masiva de precios.
-- ------------------------------------------------------------

-- Tabla de auditoria del ajuste de precios
CREATE TABLE IF NOT EXISTS auditoria_precios (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha         TIMESTAMPTZ NOT NULL DEFAULT now(),
    categoria_id  BIGINT,
    n_productos   INTEGER NOT NULL,
    total_antes   NUMERIC(16,2) NOT NULL,
    total_despues NUMERIC(16,2) NOT NULL,
    diff_promedio NUMERIC(14,2) NOT NULL
);

-- Trigger: un solo evento STATEMENT se dispara sin importar
-- cuantas filas toco el UPDATE (a diferencia de ROW triggers).
-- OLD/NEW TABLE agrupan TODAS las filas viejas y nuevas.
CREATE OR REPLACE FUNCTION fn_auditar_ajuste_precios()
RETURNS TRIGGER AS $$
DECLARE
    v_diff NUMERIC(14,2);
BEGIN
    SELECT round(avg(new_t.precio - old_t.precio), 2) INTO v_diff
    FROM old_table old_t JOIN new_table new_t ON new_t.id = old_t.id;

    INSERT INTO auditoria_precios (categoria_id, n_productos,
                                   total_antes, total_despues, diff_promedio)
    SELECT max(old_t.categoria_id),
           count(*),
           sum(old_t.precio),
           sum(new_t.precio),
           v_diff
    FROM old_table old_t JOIN new_table new_t ON new_t.id = old_t.id;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_auditar_ajuste_precios ON producto;

CREATE TRIGGER trg_auditar_ajuste_precios
AFTER UPDATE ON producto
REFERENCING OLD TABLE AS old_table NEW TABLE AS new_table
FOR EACH STATEMENT EXECUTE FUNCTION fn_auditar_ajuste_precios();

-- DEMO A: toca TODA la categoria 1 (12.500 filas) y el trigger
-- statement hace UN solo disparo (crea 1 fila en la auditoria).
BEGIN;

UPDATE producto SET precio = precio * 1.10 WHERE categoria_id = 1;

SELECT * FROM auditoria_precios;

ROLLBACK;

-- (el ROLLBACK tambien deshace la auditoria: la base queda intacta)

-- ------------------------------------------------------------
-- B) JSONB: datos semiestructurados del producto
--    Bigotes de ejemplo: info nutricional y origen.
-- ------------------------------------------------------------

-- Tabla auxiliar con datos JSONB de productos
CREATE TABLE IF NOT EXISTS producto_extra (
    producto_id BIGINT PRIMARY KEY REFERENCES producto(id),
    info        JSONB NOT NULL
);

-- Poblado de ejemplo (se conserva; no modifica el catalogo)
INSERT INTO producto_extra (producto_id, info) VALUES
    (1, '{"origen": "local", "vegano": false, "etiquetas": ["popular", "sin TACC"],
          "info_porcion": {"kcal": 850, "gramos": 320}}'),
    (2, '{"origen": "importado", "vegano": true, "etiquetas": ["premium", "sin TACC"],
          "info_porcion": {"kcal": 420, "gramos": 180}}'),
    (3, '{"origen": "local", "vegano": true, "etiquetas": ["sin azucar"],
          "info_porcion": {"kcal": 120, "gramos": 500}}')
ON CONFLICT (producto_id) DO UPDATE SET info = EXCLUDED.info;

-- DEMO B1: consumo JSONB (obtener origen y kcal)
SELECT p.id, p.nombre, e.info->>'origen'  AS origen,
       (e.info->'info_porcion'->>'kcal') AS kcal
FROM producto_extra e
JOIN producto p ON p.id = e.producto_id
ORDER BY p.id;

-- DEMO B2: filtrar con operador @> (existe la etiqueta "sin azucar")
SELECT p.id, p.nombre
FROM producto_extra e
JOIN producto p ON p.id = e.producto_id
WHERE e.info @> '{"etiquetas": ["sin azucar"]}';

-- DEMO B3: filtrar por valor de clave (veganos)
SELECT p.id, p.nombre
FROM producto_extra e
JOIN producto p ON p.id = e.producto_id
WHERE (e.info->>'vegano')::boolean = TRUE;