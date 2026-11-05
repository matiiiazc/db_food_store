# requirements.md — TP8 Food Store (tablet SQLite + semáforo)

Notación EARS. Cada requisito se prueba con el caso indicado.

## REQ-01 — Precio modificado en el servidor => CONFLICTO
- **WHEN** el precio actual de un producto en la instantánea del servidor es distinto del `precio_centavos_visto` del borrador, **THE SYSTEM SHALL** marcar la solicitud como `CONFLICTO` (con motivo), sin modificar PostgreSQL.
- **Se prueba con:** **C2** (y luego, al aceptar el cliente y actualizar el precio del borrador con una nueva solicitud, `SIMULADO_APROBADO`).

## REQ-02 — Stock insuficiente o producto no disponible/baja => RECHAZADO
- **WHEN** algún ítem de una solicitud pendiente referencia un producto inexistente, no disponible, dado de baja o con stock menor a la cantidad pedida, **THE SYSTEM SHALL** marcar la solicitud como `RECHAZADO` con el motivo correspondiente.
- **Se prueba con:** **C3** (stock insuficiente) y **C4** (producto dado de baja lógica; al recargar el catálogo el producto no aparece pero la fila queda).

## REQ-03 — Sin diferencias => SIMULADO_APROBADO (sin tocar el servidor)
- **WHEN** todos los ítems de una solicitud pendiente coinciden con la instantánea (producto existe, disponible, no eliminado, stock suficiente y precio igual al visto), **THE SYSTEM SHALL** marcar la solicitud como `SIMULADO_APROBADO` y **THE SYSTEM SHALL NOT** modificar stock, precios ni pedidos en PostgreSQL.
- **Se prueba con:** **C5** (y verificación de que los conteos/stock en PostgreSQL no cambian).

## REQ-04 — Idempotencia y re-evaluación solo de pendientes
- **WHEN** se reenvía la misma solicitud con el mismo `solicitud_uuid`, **THE SYSTEM SHALL** rechazar el duplicado por clave primaria (sin crear otra fila). **WHEN** se repite la simulación del semáforo, **THE SYSTEM SHALL** evaluar únicamente solicitudes en estado `PENDIENTE`, sin re-evaluar las ya resueltas.
- **Se prueba con:** **C6** (error de PK al duplicar UUID y la solicitud resuelta no cambia aunque cambie el snapshot).