# Informe de Concurrencia — Food Store

## Escenario 1: Lectura no repetible

### Cómo se reprodujo

**Sesión A:**
```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT stock FROM producto WHERE id = 1;
```

**Sesión B:**
```sql
BEGIN;
UPDATE producto SET stock = 50 WHERE id = 1;
COMMIT;
```

**Sesión A (continúa):**
```sql
SELECT stock FROM producto WHERE id = 1;
COMMIT;
```

### Qué se observó

| Momento | Sesión A (SELECT) | Sesión B (UPDATE) |
|---|---|---|
| Primera lectura | stock = 10 | — |
| — | — | UPDATE stock = 50; COMMIT |
| Segunda lectura | stock = 50 | — |

El mismo SELECT dentro de la misma transacción devolvió valores distintos.

### Explicación de la IA

"Con READ COMMITTED, cada lectura ve el último COMMIT en el momento de ejecutarse. Si otra sesión hace COMMIT entre las dos lecturas, el resultado cambia. Esto se llama lectura no repetible. Para evitarlo, se usa REPEATABLE READ, que toma un snapshot al inicio de la transacción y lo mantiene durante toda ella."

### Verificación en el motor

```sql
-- Sesión A con REPEATABLE READ
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT stock FROM producto WHERE id = 1;
-- stock = 10

-- Sesión B
BEGIN;
UPDATE producto SET stock = 50 WHERE id = 1;
COMMIT;

-- Sesión A (continúa)
SELECT stock FROM producto WHERE id = 1;
-- stock = 10 (no cambió)

COMMIT;
```

### Conclusión

La explicación de la IA se confirmó. Con REPEATABLE READ el resultado no cambia dentro de la transacción.

---

## Escenario 2: Lectura fantasma

### Cómo se reprodujo

**Sesión A:**
```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT COUNT(*) FROM producto WHERE activo = TRUE;
```

**Sesión B:**
```sql
BEGIN;
INSERT INTO categoria (nombre) VALUES ('Nueva');
INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Test Fantasma', 100.00, 5, TRUE, (SELECT id FROM categoria WHERE nombre = 'Nueva'));
COMMIT;
```

**Sesión A (continúa):**
```sql
SELECT COUNT(*) FROM producto WHERE activo = TRUE;
COMMIT;
```

### Qué se observó

| Momento | Sesión A (COUNT) | Sesión B (INSERT) |
|---|---|---|
| Primera lectura | COUNT = 5 | — |
| — | — | INSERT producto; COMMIT |
| Segunda lectura | COUNT = 6 | — |

Apareció una fila nueva (fantasma) que cumplía la condición del WHERE.

### Explicación de la IA

"Con READ COMMITTED, cada COUNT ve las filas commiteadas al momento de ejecutarse. Si otra sesión inserta y commitea una fila nueva entre los dos COUNT, el segundo la incluye. Esto se llama lectura fantasma. Para evitarlo, se usa SERIALIZABLE, que bloquea las filas que cumplieron el WHERE durante toda la transacción."

### Verificación en el motor

```sql
-- Sesión A con SERIALIZABLE
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM producto WHERE activo = TRUE;
-- COUNT = 5

-- Sesión B
BEGIN;
INSERT INTO categoria (nombre) VALUES ('Nueva2');
INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Test Fantasma2', 100.00, 5, TRUE, (SELECT id FROM categoria WHERE nombre = 'Nueva2'));
COMMIT;

-- Sesión A (continúa)
SELECT COUNT(*) FROM producto WHERE activo = TRUE;
-- COUNT = 5 (no cambió, pero puede fallar con error de serialización)

COMMIT;
```

### Conclusión

La explicación de la IA se confirmó. Con SERIALIZABLE el fantasma desaparece (o la transacción falla con error de serialización si detecta la anomalia).

---

## Escenario 3: Espera por bloqueo

### Cómo se reprodujo

**Sesión A:**
```sql
BEGIN;
SELECT * FROM producto WHERE id = 1 FOR UPDATE;
-- (no hace COMMIT todavía)
```

**Sesión B:**
```sql
BEGIN;
SELECT * FROM producto WHERE id = 1 FOR UPDATE;
-- SE BLOQUEA: queda esperando a que la sesión A haga COMMIT o ROLLBACK
```

### Qué se observó

| Momento | Sesión A | Sesión B |
|---|---|---|
| T=1 | `SELECT ... FOR UPDATE` → OK, bloquea fila id=1 | — |
| T=2 | (espera) | `SELECT ... FOR UPDATE` → ESPERA (bloqueado) |
| T=3 | `COMMIT` | Se desbloquea, obtiene la fila |

La sesión B quedó bloqueada hasta que la sesión A liberó el lock con COMMIT.

### Explicación de la IA

"FOR UPDATE toma un lock exclusivo sobre las filas que matchean el WHERE. Si otra sesión intenta tomar FOR UPDATE sobre la misma fila, queda en espera (no falla, solo bloquea). El lock se libera con COMMIT o ROLLBACK. Esto es un mecanismo normal de concurrencia, no es un error."

### Verificación en el motor

Se verificó que:
1. La sesión B efectivamente se bloquea (psql queda colgado esperando).
2. Al hacer COMMIT en A, B se desbloquea y recibe la fila.
3. El nivel de aislamiento no afecta este comportamiento (ocurre en READ COMMITTED y REPEATABLE READ).

### Conclusión

La explicación de la IA se confirmó. El bloqueo por FOR UPDATE es el mecanismo esperado. No es un problema a resolver, es el comportamiento correcto del motor para garantizar exclusión mutua.
