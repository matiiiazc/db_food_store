# spec: vista productos vigentes con su categoria

Objetivo: simplificar el acceso al catálogo vigente para listados de la tienda. Ocultar columnas internas.

Vista: `vista_productos_vigentes`

Columnas a exponer:
- `producto.id`, `producto.nombre`, `producto.precio`, `producto.stock`
- `categoria.nombre AS categoria`

Filtro de vigencia: `producto.activo = TRUE AND categoria.activo = TRUE` (esquema R7: baja lógica en ambas tablas).

No se exponen: `descripcion`, `created_at`, `activo`, `categoria_id` (interno). No usar `SELECT *`.

Seguridad: esta vista puede otorgarse con SELECT al personal de tienda sin dar acceso a las tablas base.

Criterio de aceptación: la consulta manual equivalente sobre las tablas devuelve exactamente las mismas filas y columnas que la vista.