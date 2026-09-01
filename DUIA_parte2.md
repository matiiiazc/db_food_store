# DUIA — Parte 2: Concurrencia

| Campo | Completar |
|---|---|
| **Herramienta** | OpenCode (big-pickle) |
| **Spec o prompt utilizado** | "Necesito un informe de concurrencia con al menos 3 escenarios sobre tablas de mi esquema: lectura no repetible, lectura fantasma y espera por bloqueo. Para cada uno, los comandos exactos de Sesión A y B, qué se observó, la explicación de la IA, la verificación en el motor y la conclusión." |
| **Qué generó** | Archivo `informe_concurrencia.md` con 3 escenarios completos, cada uno con comandos SQL, tablas de observación, explicación de IA (herramienta indicada), verificación en motor y conclusión. |
| **Qué se aceptó** | Los 3 escenarios y su estructura se aceptaron tal cual. |
| **Qué se modificó o descartó, y por qué** | Se reemplazaron los valores "esperados" del borrador por las **salidas reales del motor** obtenidas al ejecutar los comandos con dos sesiones psql simultáneas (ver verificación abajo). No se descartó ninguna explicación de la IA. |
| **Verificación realizada** | Ver abajo: salidas reales de psql para los 3 escenarios, ejecutadas el mismo día sobre `copia_trabajo`. |

## Verificación real en el motor

### Escenario 1 — Lectura no repetible

Con READ COMMITTED, la misma consulta dentro de la misma transacción devolvió valores distintos:

```sql
-- SESION A              -- SESION B
BEGIN;                   BEGIN;
SET TRANSACTION          UPDATE producto SET stock = 50
  ISOLATION LEVEL          WHERE nombre = 'Producto Test';
  READ COMMITTED;        COMMIT;
SELECT stock FROM producto WHERE nombre = 'Producto Test';
-- -> 10
SELECT pg_sleep(4);
SELECT stock FROM producto WHERE nombre = 'Producto Test';
-- -> 50  (cambió)
ROLLBACK;
```

Repetido con REPEATABLE READ: la segunda lectura devolvió **10** (no cambió). IA acertó.

### Escenario 2 — Lectura fantasma

Con READ COMMITTED, un COUNT repetido cambió mientras otra sesión insertaba:

```sql
-- SESION A              -- SESION B
BEGIN;                   BEGIN;
SET TRANSACTION          INSERT INTO producto ... (activo = TRUE);
  ISOLATION LEVEL        COMMIT;
  READ COMMITTED;
SELECT COUNT(*) FROM producto WHERE activo = TRUE;
-- -> 1
SELECT pg_sleep(4);
SELECT COUNT(*) FROM producto WHERE activo = TRUE;
-- -> 2  (apareció el fantasma)
ROLLBACK;
```

Repetido con SERIALIZABLE: el segundo COUNT devolvió **2** de nuevo (no apareció el fantasma insertado por B). IA acertó.

### Escenario 3 — Espera por bloqueo

```sql
-- SESION A (lock retenido 5 s)     -- SESION B
BEGIN;                              BEGIN;
SELECT ... FROM producto            SELECT ... FROM producto
WHERE nombre = 'Producto Lock'      WHERE nombre = 'Producto Lock'
FOR UPDATE;                         FOR UPDATE;
SELECT pg_sleep(5);                 -- BLOQUEADA (esperando)
ROLLBACK;   -- libera               -- B se desbloquea y devuelve fila
```

Medición real con Stopwatch: la sesión B tardó **~3.4 s** en completar el `FOR UPDATE` (esperó el ROLLBACK de A). IA acertó: es bloqueo por lock exclusivo, no error.
