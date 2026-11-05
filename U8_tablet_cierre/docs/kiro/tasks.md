# tasks.md — TP8 (breve)

1. **Spec (Kiro):** redactar `requirements.md` (REQ-01..04, EARS, ligados a C2–C6), `design.md`, `tasks.md`.
2. **Esquema SQLite (OpenCode, desde las tareas):** crear `movil/schema_sqlite.sql` (PRAGMA FK, 4 tablas STRICT con CHECK/FK) y ejecutar.
3. **Pruebas SQLite:** `movil/pruebas_sqlite.sql` + ejecución: BEGIN/COMMIT de borrador completo, ROLLBACK, C1 (catálogo offline), C7 (cantidad 0 y producto inexistente -> error, sin filas nuevas). Generar `foodstore_movil.db`.
4. **Snapshot PostgreSQL:** crear `v_snapshot_movil` (mapeo real), `\copy` a `servidor_snapshot.csv`, importar a `snapshot_servidor` y cargar `producto_cache` (fecha de copia anotada).
5. **Semáforo:** `movil/semaforo.sql` (PENDIENTE vs snapshot -> RECHAZADO/CONFLICTO/SIMULADO_APROBADO + motivo, solo PENDIENTE).
6. **Casos C2–C6:** simular cambios en la copia/instantánea, correr semáforo, registrar comando/resultado/explicación; verificar en PostgreSQL que pedidos/stock no cambiaron.
7. **Integración:** mapa 3 motores (3.a), plan de mantenimiento (3.b), code review con IA (3.c, >=3 hallazgos, >=2 unidades, >=1 descartado verificado).
8. **Cierre:** bitácora IA + DUIA, `README.md` (crear todo desde cero), `docs/informe.pdf` (<=6 págs) y ensayo de defensa.