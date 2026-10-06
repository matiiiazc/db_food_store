# Informe de incidente — simulacro de acceso indebido (Parte C)

Laboratorio controlado ejecutado **únicamente** contra la base de desarrollo
`food_store_tp3`. No se probó nada sobre sistemas de terceros.

## 1. Lo que realmente se ejecutó

Script `sql/simulacro_incidente.sql`, sesión `app_web` (rol de bajo
privilegio): 7 intentos fallidos contra `fn_autenticar`, 1 intento exitoso,
lectura masiva de `usuario`, intento de `GRANT admin_datos TO app_web`, y
verificación final. Resultado real:

| Paso | Operación | Resultado real |
|---|---|---|
| 1 | `fn_autenticar(...)` × 7 (password incorrecta) | `f` (7 fallos registrados en `audit_login`) |
| 2 | `fn_autenticar(...)` (password correcta) | `t` |
| 3 | `SELECT * FROM usuario;` | **ERROR: permiso denegado** (no hay exfiltración) |
| 4 | `GRANT admin_datos TO app_web;` | **ERROR: se ha denegado el permiso para otorgar el rol** |
| 5 | Verificación: `app_web` ∈ `admin_datos`? | **`false` — el escalamiento falló** |

Como el paso 4 falla, **no se detecta un defecto** en el esquema de la Parte
A: el diseño de mínimo privilegio contuvo el escalamiento. La evidencia
queda en el log del motor (SENTENCIA + ERROR) y en este informe.

## 2. Contraste: la reconstrucción de la IA vs. lo ejecutado

La IA recibió solo `docs/log_simulacro_anonimizado.txt` (respuesta íntegra en
`docs/reconstruccion_ia.md`). Comparación:

**Qué acertó**
- Los 8 intentos en ráfaga (7 fallidos + 1 exitoso) contra `cuenta_a@anon.local`
  como fuerza bruta / reuso de credenciales.
- Que el acceso se resolvió contra la autenticación de la aplicación (no
  contra el motor).
- Que el intento de escalamiento fue **denegado** por falta de opción ADMIN.
- El objetivo del atacante: tabla de identidades y rol administrativo.

**Qué omitió**
- **Toda la secuencia ocurrió en un único segundo** (19:00:24). La IA no
  notó que se trata de una **ejecución automatizada por script**, no de un
  operador humano tecleando.
- Que los 7 fallos del motor nunca dejaron rastro en el log de PostgreSQL
  (son `SELECT` de función): la evidencia está solo en `audit_login` — tabla
  que el propio atacante **tampoco pudo leer** (permiso denegado), cosa que la
  IA no mencionó.

**Qué afirmó SIN sustento (el caso más significativo del trabajo)**
- La IA dio por **exitosa la exfiltración de la tabla `usuario`**: "el
  atacante habría obtenido las filas de identidades — incluidos los hashes de
  contraseña". El fragmento de log muestra, en la línea inmediatamente
  anterior, `ERROR: permiso denegado a la tabla usuario` + `SENTENCIA:
  SELECT * FROM usuario;`. **No hubo exfiltración**: el dato sensible nunca
  salió de la base. La IA leyó el ERROR como ruido de fondo y construyó la
  etapa más grave de su hipótesis sobre una afirmación que el log no
  sustenta.
- Derivado de lo anterior, sugirió "restaurar desde copia de seguridad" — una
  medida innecesaria (y destructiva, si es mal aplicada) dado que no hubo
  modificación ni pérdida de datos.

**Cómo se detectó:** confrontando, paso a paso, cada afirmación de la IA con
la salida real del script (`permiso denegado`, `false` en la verificación de
membresía) y con el timestamp único de la sesión.

## 3. Decisión final de contención (del equipo, a partir de evidencia)

Medidas decididas y su estado:

1. **Rotar la credencial de la cuenta comprometida.** La contraseña de la
   cuenta del entorno (web@foodstore.local) quedó expuesta al patrón de
   fuerza bruta; se rotó con `fn_resetear_password`. Verificado: la password
   anterior ya devuelve `f` y el hash quedó regenerado. (Nueva credencial
   entregada fuera del repositorio.)
2. **No restaurar ninguna copia de seguridad.** No hubo pérdida ni
   alteración de datos: la contención por permisos funcionó.
3. **Confirmar membresías de roles.** Verificado con
   `pg_auth_members`: `app_web` no pertenece a `admin_datos` ni a otros
   roles administrativos.
4. **Origen.** En producción se bloquearía el origen en `pg_hba.conf` y en la
   capa de red; en este entorno el origen es loopback
   (`127.0.0.1`), por lo que la medida operativa real es el bloqueo lógico:
   **revisión de los grants emitidos por el rol** (ninguno) y monitoreo.
5. **Mitigación estructural** (a implementar fuera de este simulacro):
   bloqueo temporal de cuenta (lockout) en `fn_autenticar` tras N fallos, y
   `pgaudit` a nivel de rol/columna si se quiere registrar también las
   lecturas.

**Explícito:** esta decisión fue tomada por el equipo revisando la evidencia.
La IA propuso medidas (restauración de backup). Se aplicó la rotación de la
credencial y se descartó la restauración por innecesaria e insegura. No se
ejecutó ninguna acción automáticamente a partir de la respuesta de la IA.