-- ============================================================
-- TPI Food Store - Objetivo 8: transacciones y concurrencia
-- Escenarios A/B para dos consolas psql (Sesion A y Sesion B).
-- Los escenarios 1 y 1b cierran la sesion B con COMMIT (necesario para
-- que A observe el cambio): eso MODIFICA el stock del Producto 1.
-- Al final del script hay una linea de restauracion (stock original).
-- Todo lo demas termina en ROLLBACK y deja el esquema intacto.
-- Ejecutar primero en orden: linea por linea.
-- ============================================================

-- ------------------------------------------------------------
-- ESCENARIO 1 - Lectura no repetible (READ COMMITTED)
-- ------------------------------------------------------------
-- SESION A (consola 1)
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT stock FROM producto WHERE nombre = 'Producto 1';
-- (la sesion B ejecuta su UPDATE y COMMIT en este momento)

-- SESION B (consola 2)
BEGIN;
UPDATE producto SET stock = stock + 500 WHERE nombre = 'Producto 1';
COMMIT;

-- SESION A (continuacion)
SELECT stock FROM producto WHERE nombre = 'Producto 1';
--  ^ el valor cambio entre las dos lecturas de A
ROLLBACK;

-- ------------------------------------------------------------
-- ESCENARIO 1b - La anomalia desaparece con REPEATABLE READ
-- ------------------------------------------------------------
-- SESION A
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT stock FROM producto WHERE nombre = 'Producto 1';

-- SESION B (misma secuencia que antes)
BEGIN;
UPDATE producto SET stock = stock + 500 WHERE nombre = 'Producto 1';
COMMIT;

-- SESION A (continuacion)
SELECT stock FROM producto WHERE nombre = 'Producto 1';
--  ^ sigue viendo el valor original (snapshot al inicio de A)
ROLLBACK;

-- ------------------------------------------------------------
-- ESCENARIO 3 - Control de concurrencia con FOR UPDATE
-- ------------------------------------------------------------
-- SESION A
BEGIN;
SELECT id, nombre FROM producto
WHERE nombre = 'Producto 1'
FOR UPDATE;
--   no hace COMMIT: retiene el lock sobre la fila

-- SESION B
BEGIN;
SELECT id, nombre FROM producto
WHERE nombre = 'Producto 1'
FOR UPDATE;
--   SE QUEDA BLOQUEADO esperando ~3,4 s hasta que A libere

-- SESION A
ROLLBACK;

-- SESION B (se desbloquea y devuelve la fila)
SELECT id, nombre FROM producto WHERE nombre = 'Producto 1';
ROLLBACK;

-- ------------------------------------------------------------
-- ATOMICIDAD - ver con fn_impedir_delete_logico
-- Un DELETE fisico levanta excepcion y aborta la transaccion.
-- ------------------------------------------------------------
BEGIN;
DELETE FROM producto WHERE id = 1;   -- ERROR: no esta permitido
-- la transaccion aborto completa (ninguna instruccion se aplico)
ROLLBACK;

-- ------------------------------------------------------------
-- RESTAURACION: devuelve al Producto 1 su stock original
-- Los escenarios 1 y 1b commitean +500 y +500 en la sesion B.
-- Ejecutar en la Sesion B (o en una consola libre) al terminar.
-- ------------------------------------------------------------
UPDATE producto SET stock = stock - 1000 WHERE nombre = 'Producto 1';