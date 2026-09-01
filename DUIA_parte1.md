# DUIA — Parte 1: Integridad versionada

| Campo | Completar |
|---|---|
| **Herramienta** | OpenCode (big-pickle) |
| **Spec o prompt utilizado** | "Necesito una restricción que impida el DELETE directo en categoria y producto (forzar baja lógica vía activo = FALSE), que al insertar un detalle_pedido se descuente el stock y se verifique que no quede negativo, y que el subtotal de detalle_pedido siempre sea igual a cantidad x precio_unitario." |
| **Qué generó** | Archivo `restricciones.sql` con 3 funciones PL/pgSQL y 4 triggers: `fn_impedir_delete_logico` (triggers en `categoria` y `producto`), `fn_descontar_stock` (trigger en `detalle_pedido`), `fn_verificar_subtotal` (trigger en `detalle_pedido`). |
| **Qué se aceptó** | Las 3 reglas y los 4 triggers se aceptaron tal cual. |
| **Qué se modificó o descartado, y por qué** | Se reescribieron los mensajes de `RAISE EXCEPTION` con texto sin acentos y el archivo se guardó en UTF-8 sin BOM, porque el encoder del cliente psql en Windows fallaba con la codificación original (equivalente a lo que ya pasaba con `schema.sql`). La lógica no cambió. |
| **Verificación realizada** | `test_restricciones.sql` ejecutado sobre `copia_trabajo` dentro de una transacción con SAVEPOINTs. Resultados reales: ver abajo. |

## Verificación ejecutada (salida real de psql)

### Test 1: Baja lógica — DELETE directo (debe FALLAR)

```sql
BEGIN;
INSERT INTO categoria (nombre) VALUES ('Pizzas');
SAVEPOINT test1;
DELETE FROM categoria WHERE nombre = 'Pizzas';
ROLLBACK TO test1;
```

Resultado: **ERROR** "No esta permitido eliminar registros fisicamente. Use UPDATE ... SET activo = FALSE." — la regla rechazó el DELETE. OK.

### Test 2: Baja lógica — UPDATE lógico (debe FUNCIONAR)

```sql
UPDATE categoria SET activo = FALSE WHERE nombre = 'Bebidas';
```

Resultado: `UPDATE 1` — la baja lógica se permite. OK.

### Test 3: Stock — pedido válido (debe FUNCIONAR)

```sql
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
VALUES (pedido_id, producto_id_muzzarella, 3, 800.00, 2400.00);

SELECT nombre, stock FROM producto WHERE nombre = 'Muzzarella';
```

Resultado: `INSERT 0 1` y stock pasó de 10 a **7** (10 - 3). OK.

### Test 4: Stock — pedido con stock insuficiente (debe FALLAR)

```sql
SAVEPOINT test4;
INSERT INTO detalle_pedido (...) VALUES (..., 'Coca-Cola', 100, 500.00, 50000.00);
ROLLBACK TO test4;
```

Resultado: **ERROR** "Stock insuficiente para el producto id=4. Stock actual: 20, cantidad pedida: 100" — la regla rechazó el pedido. OK.

### Test 5: Subtotal — subtotal incorrecto (debe FALLAR)

```sql
SAVEPOINT test5;
INSERT INTO detalle_pedido (...) VALUES (..., 'Coca-Cola', 2, 500.00, 9999.00);
ROLLBACK TO test5;
```

Resultado: **ERROR** "El subtotal (9999.00) no coincide con cantidad (2) x precio_unitario (500.00). Resultado esperado: 1000.00" — la regla rechazó el subtotal. OK.

### Test 6: Subtotal — subtotal correcto (debe FUNCIONAR)

```sql
INSERT INTO detalle_pedido (...) VALUES (..., 'Coca-Cola', 2, 500.00, 1000.00);
```

Resultado: `INSERT 0 1` — Coca-Cola quedó con stock 18 (20 - 2). OK.

## Resumen

- Las 3 reglas quedaron garantizadas por el motor (5 triggers: 2 de baja lógica, 1 de stock, 2 de subtotal INSERT/UPDATE).
- Los tests 1, 4 y 5 probaron los casos inválidos y el motor los rechazó.
- Los tests 2, 3 y 6 probaron los casos válidos y el motor los aceptó.
- Todo se ejecutó sobre `copia_trabajo` y cerró con ROLLBACK, sin dejar datos.