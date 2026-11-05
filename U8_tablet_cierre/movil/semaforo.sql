-- semaforo.sql (Consigna 2.b)
-- Compara solicitudes PENDIENTE con snapshot_servidor y actualiza cola_sync.
-- Rojo=RECHAZADO, Amarillo=CONFLICTO, Verde=SIMULADO_APROBADO. No toca PostgreSQL.
PRAGMA foreign_keys = ON;

UPDATE cola_sync
SET estado = v.nuevo_estado,
    motivo = v.motivo
FROM (
  SELECT c.solicitud_uuid,
    CASE
      WHEN SUM(CASE WHEN s.id IS NULL
                      OR s.disponible = 0
                      OR s.eliminado = 1
                      OR i.cantidad > s.stock THEN 1 ELSE 0 END) > 0
        THEN 'RECHAZADO'
      WHEN SUM(CASE WHEN s.id IS NOT NULL
                      AND i.precio_centavos_visto <> s.precio_centavos THEN 1 ELSE 0 END) > 0
        THEN 'CONFLICTO'
      ELSE 'SIMULADO_APROBADO'
    END AS nuevo_estado,
    CASE
      WHEN SUM(CASE WHEN s.id IS NULL THEN 1 ELSE 0 END) > 0
        THEN 'producto inexistente en snapshot'
      WHEN SUM(CASE WHEN s.eliminado = 1 OR s.disponible = 0 THEN 1 ELSE 0 END) > 0
        THEN 'producto no disponible o dado de baja'
      WHEN SUM(CASE WHEN i.cantidad > s.stock THEN 1 ELSE 0 END) > 0
        THEN 'stock insuficiente'
      WHEN SUM(CASE WHEN i.precio_centavos_visto <> s.precio_centavos THEN 1 ELSE 0 END) > 0
        THEN 'precio cambiado (conflicto)'
      ELSE 'todo coincide con el servidor'
    END AS motivo
  FROM cola_sync c
  JOIN item_borrador i  ON i.id_local = c.id_local
  LEFT JOIN snapshot_servidor s ON s.id = i.producto_id
  WHERE c.estado = 'PENDIENTE'          -- solo PENDIENTE: re-ejecutar no reevalúa resueltos
  GROUP BY c.solicitud_uuid
) AS v
WHERE cola_sync.solicitud_uuid = v.solicitud_uuid;

-- Resultado
SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync ORDER BY rowid;
