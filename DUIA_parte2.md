# DUIA — Parte 2: Concurrencia

| Campo | Completar |
|---|---|
| **Herramienta** | OpenCode (big-pickle) |
| **Spec o prompt utilizado** | "Necesito un informe de concurrencia con al menos 3 escenarios sobre tablas de mi esquema: lectura no repetible, lectura fantasma y espera por bloqueo. Para cada uno, los comandos exactos de Sesión A y B, qué se observó, la explicación de la IA, la verificación en el motor y la conclusión." |
| **Qué generó** | Archivo `informe_concurrencia.md` con 3 escenarios completos, cada uno con comandos SQL, tablas de observación, explicación de IA, verificación en motor y conclusión. |
| **Qué se aceptó** | Los 3 escenarios y su estructura se aceptaron tal cual. |
| **Qué se modificó o descartó, y por qué** | No se modificó nada. |
| **Verificación realizada** | Cada escenario se verificó ejecutando los comandos en dos sesiones psql simultáneas sobre `copia_trabajo` con READ COMMITTED, y luego repitiendo con REPEATABLE READ o SERIALIZABLE según corresponda. |
