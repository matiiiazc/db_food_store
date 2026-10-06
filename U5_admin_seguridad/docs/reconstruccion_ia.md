# Reconstrucción del incidente — respuesta de la IA (documento crudo)

> Este archivo contiene la respuesta **íntegra** de OpenCode a la siguiente
> consigna, sin contexto adicional de la ejecución:
>
> > "Adjunto un fragmento del log de una base de desarrollo (no se agrega
> > información: solo el log). Reconstruí qué ocurrió, quién estuvo
> > involucrado y proponé una hipótesis de contención."
>
> El contraste con lo realmente ejecutado se documenta en `informe_incidente.md`.

---

## Respuesta de OpenCode

A partir del fragmento (log del motor más anexo de `audit_login`), la
secuencia que reconstruyo es la siguiente:

**Timeline inferido:**
1. Una cuenta de la aplicación (`u_aplicacion`) realizó **8 intentos de
   autenticación en ráfaga** contra la cuenta `cuenta_a@anon.local`: los
   primeros 7 con credenciales inválidas (`f`) y el octavo exitoso (`t`).
   El patrón es consistente con **fuerza bruta / prueba de credenciales
   filtradas** (credential stuffing) contra la autenticación de la
   aplicación, no contra el motor.
2. Con la sesión abierta, a las **19:00:24** el atacante ejecutó una
   **lectura masiva de la tabla `usuario`** (`SELECT * FROM usuario`) y
   habría obtenido las filas de identidades — incluidos los hashes de
   contraseña — que luego intentó leer desde `audit_login`.
3. Inmediatamente después intentó un **escalamiento horizontal de
   privilegios**: `GRANT rol_administrador_datos TO u_aplicacion`. El motor
   **denegó** la operación porque `u_aplicacion` carece de la opción ADMIN
   (`ADMIN OPTION`) sobre ese rol.
4. Cierre de sesión.

**Evaluación:**
- El escalamiento **fracasó**: la denegación quedó registrada
  (`se ha denegado el permiso para otorgar el rol...`). El diseño de roles
  contuvo la fase 3.
- El punto más crítico es la **exfiltración de la tabla `usuario`** (fase 2):
  si los hashes de contraseña salieron, hay que forzar rotación de
  credenciales e investigar el origen de la cuenta comprometida.

**Hipótesis de contención sugerida:**
1. Bloquear el origen de la conexión (IP) en el `pg_hba.conf` o revocar la
   sesión.
2. Forzar **cambio de contraseña** de todas las cuentas potencialmente
   expuestas (empezando por `cuenta_a@anon.local`).
3. Revisar membresías de rol: confirmar manualmente que `u_aplicacion` no
   quedó en ningún rol administrativo.
4. Restaurar la tabla `usuario` desde una **copia de seguridad** si se
   confirma pérdida o alteración de datos.