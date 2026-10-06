# Informe — Auditoría nativa activada en Food Store (Parte B)

## 1. Parámetros modificados en el servidor de desarrollo

Se modificaron, vía `ALTER SYSTEM` + `pg_reload_conf()` (persistidos en
`postgresql.auto.conf`, efectivos sin reiniciar):

| Parámetro | Valor anterior | Valor aplicado | Efecto |
|---|---|---|---|
| `log_connections` | `off` | `on` | Registra cada conexión recibida, autenticada y autorizada |
| `log_disconnections` | `off` | `on` | Registra la desconexión con duración de sesión |
| `log_statement` | `none` | `mod` | Registra las sentencias que modifican datos (INSERT/UPDATE/DELETE y DDL) |

SQL aplicado:

```sql
ALTER SYSTEM SET log_connections    = on;    SELECT pg_reload_conf();
ALTER SYSTEM SET log_disconnections = on;    SELECT pg_reload_conf();
ALTER SYSTEM SET log_statement      = 'mod'; SELECT pg_reload_conf();
```

Verificación: `SHOW log_connections = on`, `SHOW log_disconnections = on`,
`SHOW log_statement = mod` (origen: configuration file). El log quedó en
`data/log/postgresql-2026-10-06_114319.log` (`log_destination=stderr`,
`log_directory=log`).

## 2. Prueba ejecutada sobre `food_store_tp3`

Secuencia (archivo `sql/auditoria_test.sql`, más el login fallido):
`lectura → inserción (pedido) → actualización (producto) → UPDATE no
autorizado sobre usuario → UPDATE autorizado de soporte → login fallido`.
Fragmento capturado: `docs/log_auditoria_prueba.txt`.

## 3. Qué aporta este fragmento a los fines de auditoría

Del fragmento se reconstruye la tríada completa *quién · qué · cuándo · desde
dónde*:

- **Quién**: `conexión autorizada: usuario=app_web / admin_datos` (identidad
  del motor, no un alias de aplicación).
- **Qué**: `sentencia: UPDATE usuario SET activo = TRUE WHERE id = 107` — el
  texto completo de cada sentencia de modificación, incluida la **reintención
  del UPDATE no autorizado** (permiso denegado), que queda como ERROR con su
  sentencia.
- **Cuándo**: timestamp con zona (`2026-10-06 18:57:06 -03`).
- **Desde dónde**: `host=127.0.0.1 port=61701` (origen IP + puerto efímero).
- **Resultado**: éxito (LOG) o fallo (ERROR / FATAL, como el intento de
  login con password incorrecta).

## 4. Alcance y límites del mecanismo nativo

Con `log_statement='mod'` **no quedan registradas las lecturas** (SELECT
puro) — solo modificación; tampoco el detalle fila por fila (qué tuplas
cambió cada UPDATE), ni los valores de los parámetros de sentencias
preparadas. Para mayor granularidad la extensión **pgaudit** (rol log),
configurable por rol/objeto, registra lee-rees y, combinada con
`pgaudit.log_row_level`, el detalle de filas afectadas y la categoría de
objeto. El registro nativo es un buen **registro técnico**; con pgaudit se
acerca a la **rendición de cuentas**, con costo de volumen y de diseño de
retención.

## 5. ¿El propio log es un activo sensible? ¿Quién debe poder leerlo?

Sí: contiene texto completo de sentencias (con valores de datos), nombres de
usuario, hosts e IPs; es información personal y operativa. Solo el rol
administrador del motor (o un rol de auditoría dedicado si se implementa) y
el administrador del sistema operativo deberían leerlo. En el sistema de
archivos debe quedar con permiso de lectura **solo para el usuario/grupo del
servicio de PostgreSQL** (equivalente a `640` owner, nunca `world-readable`;
en Windows, ACL restringida a la cuenta de servicio), y el acceso por SQL a
la carpeta y a objetos de auditoría debe seguir la misma política de mínimo
privilegio definida en la Parte A.

Volver a los valores por defecto (devolver el entorno a su estado inicial):
`ALTER SYSTEM RESET log_connections; ALTER SYSTEM RESET log_disconnections;
ALTER SYSTEM RESET log_statement; SELECT pg_reload_conf();`