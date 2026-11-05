# design.md — TP8 (breve)

## Arquitectura
- **Servidor (fuente de verdad):** PostgreSQL `food_store_tp3`. Expone `v_snapshot_movil` (productos: id, nombre, precio_centavos, stock, disponible, eliminado). Nunca es modificado por la tablet.
- **Tablet (offline):** SQLite `foodstore_movil.db` (`STRICT`, `PRAGMA foreign_keys=ON`). Tablas: `producto_cache` (réplica), `pedido_borrador`+`item_borrador` (borradores locales), `cola_sync` (solicitudes con estado/motivo), `snapshot_servidor` (instantánea importada para comparar).
- **Flujo:** exportar `v_snapshot_movil` -> CSV -> importar `snapshot_servidor` -> recargar `producto_cache`. El borrador genera una solicitud `PENDIENTE` en `cola_sync`. El semáforo compara `item_borrador` (vía solicitudes PENDIENTE) contra `snapshot_servidor` y escribe `RECHAZADO|CONFLICTO|SIMULADO_APROBADO` + motivo. `SIMULADO_APROBADO` **no** es una venta.

## Decisiones
- Precios en **centavos (INTEGER)** para evitar flotantes.
- `solicitud_uuid` como PK => idempotencia local; solo se procesan `PENDIENTE`.
- Mapeo real: `disponible=(activo AND stock>0)`, `eliminado=NOT activo`; conversión `ROUND(precio*100)`.
- Reglas de semáforo: rojo (inexistente/no disponible/baja/stock insuficiente) > amarillo (precio distinto) > verde (coincide). Se implementa con agregación `CASE/SUM` + `LEFT JOIN` y `UPDATE ... FROM` (SQLite 3.33+).