# spec: vista pedidos con datos del cliente

Objetivo: reportes de pedidos cruzados con la identidad del cliente para el área de CX/atención al cliente.

Vista: `vista_pedidos_cliente`

Columnas a exponer:
- `pedido.id AS pedido_id`, `pedido.fecha`, `pedido.forma_pago`
- `cliente.nombre`, `cliente.apellido`, `cliente.email`

Filtro de vigencia: no hay baja lógica en `pedido`/`cliente` (el esquema R7 aplica solo a `categoria` y `producto`); incluir **todos** los pedidos.

No se expone **por seguridad**: `cliente.telefono` (dato de contacto sensible) — la vista permite otorgar SELECT sin exponer el dato privado del cliente. No usar `SELECT *`.

Criterio de aceptación: la consulta manual equivalente devuelve exactamente las mismas filas y columnas que la vista.