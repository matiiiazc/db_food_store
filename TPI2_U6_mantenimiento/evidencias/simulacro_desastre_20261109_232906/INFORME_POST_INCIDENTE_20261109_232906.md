# INFORME POST-INCIDENTE - Simulacro de desastre U6 (datos medidos)

## Identificacion
- Fecha/hora inicio simulacro: 2026-11-09T23:29:30.6198557-03:00
- Ultimo backup utilizado: C:\Users\PC\Desktop\Uni\Bases de datos II\food_store\TPI2_U6_mantenimiento\evidencias\backup_food_store_tp3_20261109_232703\food_store_tp3_20261109_232703.dump (dir: C:\Users\PC\Desktop\Uni\Bases de datos II\food_store\TPI2_U6_mantenimiento\evidencias\backup_food_store_tp3_20261109_232703)
- Base restaurada (NUEVA): food_store_tp3_restore_sim_20261109_232906 (NO se toco food_store_tp3)
- Host/puerto/usuario: 127.0.0.1/5432/postgres

## Tiempos (contra reloj)
- Tiempo total simulacro (ms/s): 22933 ms / 22.933 s
- Tiempo de restauracion (pg_restore/flujo script) (ms/s): 21616 ms / 21.617 s

## Resultados de ejecucion (medidos)
- restore_foodstore.ps1 exit: 0 (ver log del restore)
- verificacion post-restore exit: 0
- Salidas: ver 'C:\Users\PC\Desktop\Uni\Bases de datos II\food_store\TPI2_U6_mantenimiento\evidencias\simulacro_desastre_20261109_232906\verif_post_restore_sim_20261109_232906.txt' y logs asociados

## Verificaciones a completar (HUMANAS, sin inventar) — COMPLETADAS CON EVIDENCIA REAL (2026-11-09 23:31)
- [x] Conteos origen vs restaurada coinciden (tabla [2]): **IGUAL 5/5** (categoria=4, cliente=20000, producto=50000, pedido=200401, detalle_pedido=601205; 0 diferencias). Inventario de objetos también igual: 13 tablas, 5 vistas, 2 MV, 44 funciones, 5 triggers, 29 índices.
- [x] PK/FK/CHECK/UNIQUE/vistas/MV/funciones/triggers/indices coherentes: diff completo `compare_origen_sim` vs `verif_post_restore_sim` = solo 22 líneas distintas, todas en sección [1] (nombre de la base, esperado) y [3] (`reltuples` = estimaciones del planificador: origen con estadísticas rancias `-1`/viejas; restaurada con estimaciones frescas post-restore). **Sin diferencias de datos ni de objetos.**
- [x] ENUM forma_pago_enum correcto: EFECTIVO(1), TARJETA(2), TRANSFERENCIA(3) — sección [10].
- [~] Chequeos integridad ([12]): **huérfanos = 0 filas ✓**; **subtotales incoherentes = 533.524 filas, pero IDÉNTICAS en origen y restaurada** (conteo verificado en ambas: 533524 = 533524). Desvío **pre-existente** de la carga masiva del TP3 (subtotal generado aleatorio, independiente de cantidad×precio_unitario); **no** es un defecto del respaldo/restauración (la restauración fue fiel). Documentado como hallazgo de calidad de datos, no de recuperación.
- [x] Origen food_store_tp3 sin modificaciones: conteos finales vs línea base 23:12:11 → `ORIGEN_SIN_CAMBIOS=TRUE` (5/5 tablas IGUAL).

## Lecciones/aprendizajes, contencion, acciones correctivas
- Observaciones: el pipeline completo (backup programado → verificación → restore → verificación post-restore → comparación) funciona end-to-end; las guardas bloquean correctamente destinos prohibidos. Durante la corrida se detectaron y corrigieron 5 fallos reales de infraestructura/scripting (PS 5.1): operador `??`, `NativeCommandError` con stderr+EAP Stop, colisión de función `R` con alias `r` (falso "SUPERADAS"), `$PSScriptRoot` vacío en defaults bajo `powershell.exe -File` (rompía la tarea programada; corregido moviendo la resolución de rutas al cuerpo) y un bug propio de un comando comparativo ad-hoc. Detalle completo en `evidencias/RESUMEN_CORRIDA_U6_20261109.md`.
- Desvios detectados: (1) incoherencia `subtotal` pre-existente en datos del TP3 (533.524 filas, igual en origen y restaurada — ver arriba); (2) estadísticas del planificador rancias en el origen (`reltuples=-1`) → justifica el `ANALYZE` del mantenimiento rutinario (ejecutado sobre la restaurada).
- Acciones correctivas: scripts corregidos y re-probados; tarea de prueba eliminada tras verificar; respaldo diario productivo pendiente de registrar (`programar_backup.ps1 -At 02:30`, decisión operativa); para calidad de datos, eventual corrección de `subtotal` en una copia (fuera de alcance de U6, requiere decisión de negocio sobre datos históricos facturados).

---
Generado por simulacro_desastre.ps1. No se han inventado 'superado/fallado' automaticos: completar la seccion humana con evidencias.
