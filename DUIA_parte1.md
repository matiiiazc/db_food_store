# DUIA — Parte 1: Integridad versionada

| Campo | Completar |
|---|---|
| **Herramienta** | OpenCode (big-pickle) |
| **Spec o prompt utilizado** | "Necesito una restricción que impida el DELETE directo en categoria y producto (forzar baja lógica), que al insertar un detalle_pedido se descuente el stock y se verifique que no sea negativo, y que el subtotal siempre sea igual a cantidad × precio_unitario." |
| **Qué generó** | Archivo `restricciones.sql` con 3 funciones PL/pgSQL y 4 triggers: `fn_impedir_delete_logico` (triggers en `categoria` y `producto`), `fn_descontar_stock` (trigger en `detalle_pedido`), `fn_verificar_subtotal` (trigger en `detalle_pedido`). |
| **Qué se aceptó** | Las 3 reglas y los 4 triggers se aceptaron tal cual. |
| **Qué se modificó o descartó, y por qué** | No se modificó nada. |
| **Verificación realizada** | Ver abajo (tests de cada regla) |

## Verificación

### Regla 1: Baja lógica

```sql
-- Setup
BEGIN;
INSERT INTO categoria (nombre) VALUES ('Test Borrado');

-- Test: DELETE directo (debe fallar)
DELETE FROM categoria WHERE nombre = 'Test Borrado';
-- Resultado esperado: ERROR "No está permitido eliminar registros físicamente..."

-- Test: UPDATE lógico (debe funcionar)
UPDATE categoria SET activo = FALSE WHERE nombre = 'Test Borrado';
-- Resultado: OK, 1 fila afectada

ROLLBACK;
```

### Regla 2: Stock

```sql
BEGIN;
-- Setup: crear categoría, producto con stock 10, cliente y pedido
INSERT INTO categoria (nombre) VALUES ('Test Stock');
INSERT INTO producto (nombre, precio, stock, categoria_id)
VALUES ('Hamburguesa', 500.00, 10, (SELECT id FROM categoria WHERE nombre = 'Test Stock'));
INSERT INTO cliente (nombre, apellido, email) VALUES ('Test', 'User', 'test@stock.com');
INSERT INTO pedido (forma_pago, cliente_id)
VALUES ('EFECTIVO', (SELECT id FROM cliente WHERE email = 'test@stock.com'));

-- Test: INSERT válido (debe funcionar y stock baja a 7)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Hamburguesa'),
    3, 500.00, 1500.00
);
-- Resultado: OK

-- Verificar stock
SELECT stock FROM producto WHERE nombre = 'Hamburguesa';
-- Resultado: 7

-- Test: INSERT con stock insuficiente (debe fallar)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Hamburguesa'),
    100, 500.00, 50000.00
);
-- Resultado esperado: ERROR "Stock insuficiente..."

ROLLBACK;
```

### Regla 3: Subtotal consistente

```sql
BEGIN;
-- Setup (mismos datos que regla 2)

-- Test: subtotal incorrecto (debe fallar)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Hamburguesa'),
    3, 500.00, 9999.00  -- 3 × 500 = 1500, no 9999
);
-- Resultado esperado: ERROR "El subtotal no coincide..."

-- Test: subtotal correcto (debe funcionar)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (
    (SELECT id FROM pedido ORDER BY id DESC LIMIT 1),
    (SELECT id FROM producto WHERE nombre = 'Hamburguesa'),
    3, 500.00, 1500.00
);
-- Resultado: OK

ROLLBACK;
```
