# spec: vista detalle de un pedido con nombre del producto

Objetivo: consultar las líneas de un pedido con el nombre del producto (ticket / detalle), sin exponer ids internos.

Vista: `vista_detalle_pedido`

Columnas a exponer:
- `pedido_id`, `producto.nombre AS producto`, `cantidad`
- `precio_unitario`, `subtotal`

Filtro de vigencia: **no** filtrar por `producto.activo` — el histórico facturado debe mostrarse aunque el producto haya quedado inactivo después. Esto preserva la integridad del ticket.

No se exponen: `detalle_pedido.id`, `producto_id` interno, `descripcion`. No usar `SELECT *`.

Criterio de aceptación: la consulta manual equivalente devuelve exactamente las mismas filas y columnas que la vista.