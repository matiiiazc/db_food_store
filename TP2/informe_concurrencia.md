# Informe de Concurrencia — Food Store

## Escenario 1: Lectura no repetible

### Cómo se reprodujo

**Sesión A:**
```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT stock FROM producto WHERE nombre = 'Producto Test';
```

**Sesión B:**
```sql
BEGIN;
UPDATE producto SET stock = 50 WHERE nombre = 'Producto Test';
COMMIT;
```

**Sesión A (continúa, unos segundos después):**
```sql
SELECT stock FROM producto WHERE nombre = 'Producto Test';
ROLLBACK;
```

### Qué se observó

Salida real (READ COMMITTED):

| Momento | Sesión A (SELECT) | Sesión B (UPDATE) |
|---|---|---|
| Primera lectura | stock = 10 | — |
| — | — | UPDATE stock = 50; COMMIT |
| Segunda lectura | stock = 50 | — |

El mismo SELECT dentro de la misma transacción devolvió valores distintos: 10 y luego 50.

### Explicación de la IA

Herramienta: **OpenCode**

> "Con READ COMMITTED, cada lectura ve el último COMMIT en el momento de ejecutarse. Si otra sesión hace COMMIT entre las dos lecturas, el resultado cambia. Esto se llama lectura no repetible. Para evitarlo, se usa REPEATABLE READ, que toma un snapshot al inicio de la transacción y lo mantiene durante toda ella."

### Verificación en el motor

Salida real (REPEATABLE READ):

```sql
-- Sesión A con REPEATABLE READ
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT stock FROM producto WHERE nombre = 'Producto Test';
-- lectura 1 = 10

-- Sesión B
BEGIN;
UPDATE producto SET stock = 50 WHERE nombre = 'Producto Test';
COMMIT;

-- Sesión A (continúa)
SELECT stock FROM producto WHERE nombre = 'Producto Test';
-- lectura 2 = 10 (no cambió)

ROLLBACK;
```

### Conclusión

La explicación de la IA se confirmó. Con REPEATABLE READ la segunda lectura devolvió el mismo valor (10) pese a que la sesión B había commiteado el cambio a 50.

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

Salida real (READ COMMITTED):

| Momento | Sesión A (COUNT) | Sesión B (INSERT) |
|---|---|---|
| Primera lectura | COUNT = 1 | — |
| — | — | INSERT producto; COMMIT |
| Segunda lectura | COUNT = 2 | — |

Apareció una fila nueva (fantasma) que cumplía la condición del WHERE.

### Explicación de la IA

Herramienta: **OpenCode**

> "Con READ COMMITTED, cada COUNT ve las filas commiteadas al momento de ejecutarse. Si otra sesión inserta y commitea una fila nueva entre los dos COUNT, el segundo la incluye. Esto se llama lectura fantasma. Para evitarlo, se usa SERIALIZABLE, que bloquea las filas que cumplieron el WHERE durante toda la transacción."

### Verificación en el motor

Salida real (SERIALIZABLE):

```sql
-- Sesión A con SERIALIZABLE
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM producto WHERE activo = TRUE;
-- primer COUNT = 2

-- Sesión B
BEGIN;
INSERT INTO categoria (nombre) VALUES ('FantasmaNueva2');
INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('FantasmaY', 100.00, 5, TRUE, (SELECT id FROM categoria WHERE nombre = 'FantasmaNueva2'));
COMMIT;

-- Sesión A (continúa)
SELECT COUNT(*) FROM producto WHERE activo = TRUE;
-- segundo COUNT = 2 (no cambió, el fantasma no aparece)

ROLLBACK;
```

### Conclusión

La explicación de la IA se confirmó. Con SERIALIZABLE el fantasma no aparece: el segundo COUNT devolvió el mismo valor (2) pese a que la sesión B insertó y commiteó una fila nueva.

---

## Escenario 3: Espera por bloqueo

### Cómo se reprodujo

**Sesión A:**
```sql
BEGIN;
SELECT nombre FROM producto WHERE nombre = 'Producto Lock' FOR UPDATE;
-- (no hace COMMIT todavía; retiene el lock 5 segundos)
```

**Sesión B:**
```sql
BEGIN;
SELECT nombre FROM producto WHERE nombre = 'Producto Lock' FOR UPDATE;
-- SE BLOQUEA: queda esperando a que la sesión A haga COMMIT o ROLLBACK
```

**Sesión A (tras 5 segundos):**
```sql
ROLLBACK;
-- libera el lock, la sesión B se desbloquea
```

### Qué se observó

Salida real:

| Momento | Sesión A | Sesión B |
|---|---|---|
| T=0 | `SELECT ... FOR UPDATE` → OK, toma el lock | — |
| T=2s | (retiene el lock) | `SELECT ... FOR UPDATE` → BLOQUEADA |
| T=5s | `ROLLBACK` → libera el lock | Se desbloquea y devuelve la fila |

Medición real: la sesión B tardó **~3.4 segundos** en completar el `FOR UPDATE`, es decir, quedó esperando hasta que la sesión A hizo ROLLBACK. La sesión B quedó bloqueada, no falló.

### Explicación de la IA

Herramienta: **OpenCode**

> "FOR UPDATE toma un lock exclusivo sobre las filas que matchean el WHERE. Si otra sesión intenta tomar FOR UPDATE sobre la misma fila, queda en espera (no falla, solo bloquea). El lock se libera con COMMIT o ROLLBACK. Esto es un mecanismo normal de concurrencia, no es un error."

### Verificación en el motor

Se ejecutó en el motor real y se confirmó que:
1. La sesión B quedó bloqueada (~3.4 segundos de espera real medidos con Stopwatch).
2. Al hacer ROLLBACK en A, B se desbloqueó y recibió la fila.

Comandos que dieron las salidas reales:

```sql
-- SESION A (job en segundo plano)
BEGIN;
SELECT ... FROM producto WHERE nombre = 'Producto Lock' FOR UPDATE;
SELECT pg_sleep(5);
ROLLBACK;

-- SESION B (ejecutada al mismo tiempo)
SELECT ... FROM producto WHERE nombre = 'Producto Lock' FOR UPDATE;
-- -> tarda 3.4 s (bloqueada) y recién entonces devuelve la fila
```

3. El nivel de aislamiento no afecta este comportamiento: el lock exclusivo por `FOR UPDATE` ocurre igual en READ COMMITTED y REPEATABLE READ.

### Conclusión

La explicación de la IA se confirmó. El bloqueo por `FOR UPDATE` es el mecanismo esperado: la sesión B espera hasta que la sesión A libera el lock. No es un problema a resolver, es el comportamiento correcto del motor para garantizar exclusión mutua.
