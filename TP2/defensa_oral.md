# Defensa Oral — TP2 Concurrencia e IA como motor primario

## 1. Presentación general

El TP2 trabaja sobre el esquema del proyecto integrador Food Store. Tiene tres partes:
- **Parte 1**: garantizar en el motor (con triggers) reglas de negocio que antes dependían de la aplicación.
- **Parte 2**: reproducir anomalías de concurrencia con dos sesiones y verificar la explicación de la IA contra el motor real.
- **Parte 3**: lectura crítica de scripts peligrosos generados por IA.

En todos los pasos se aplicó el protocolo de seguridad de la cátedra: **copia, transacción y respaldo**. El trabajo se realizó siempre sobre `copia_trabajo`, nunca sobre la base original.

---

## 2. Parte 1 — restricciones.sql línea por línea

Se eligieron **tres reglas de negocio** que el esquema no garantizaba:

1. **Baja lógica**: impedir el `DELETE` físico sobre `categoria` y `producto`.
2. **Stock**: al cargar un `detalle_pedido`, descontar el stock y verificar que no quede negativo.
3. **Subtotal**: el `subtotal` de `detalle_pedido` debe ser siempre `cantidad × precio_unitario`.

### Líneas 15-21 — función `fn_impedir_delete_logico`

```sql
CREATE OR REPLACE FUNCTION fn_impedir_delete_logico()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'No esta permitido eliminar registros fisicamente. Use UPDATE ... SET activo = FALSE.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
```

- `CREATE OR REPLACE FUNCTION`: crea o reemplaza la función. Lar `OR REPLACE` permite corregirla sin borrarla ni romper los triggers que la usan.
- `RETURNS TRIGGER AS $$ ... $$ LANGUAGE plpgsql`: es una función de trigger escrita en PL/pgSQL. El `$$` es solo el delimitador del cuerpo.
- `RAISE EXCEPTION`: lanza un error que aborta la operación que disparó el trigger. Es la forma de "no dejar hacer" el DELETE.
- `RETURN NULL`: en un `BEFORE DELETE` devolver `NULL` significa "no elimines la fila". Combinado con el `RAISE` anterior, nunca se llega a ejecutar (el error corta), pero es la forma correcta de anular el DELETE como red de seguridad.

**Si se sacara** el `RAISE`, la función devolvería `NULL` y el DELETE quedaría silenciosamente anulado en todos los casos... pero como el `RAISE` es el que da el mensaje, sacarlo no solo quitaría el aviso sino que haría imposible eliminar discriminando casos. El punto clave: sin este trigger, un `DELETE FROM categoria` **borraría físicamente** la categoría y rompería el historial de productos que la referencian (regla R7).

### Líneas 23-31 — triggers de baja lógica

```sql
CREATE TRIGGER trg_categoria_no_delete
    BEFORE DELETE ON categoria
    FOR EACH ROW
    EXECUTE FUNCTION fn_impedir_delete_logico();

CREATE TRIGGER trg_producto_no_delete
    BEFORE DELETE ON producto
    FOR EACH ROW
    EXECUTE FUNCTION fn_impedir_delete_logico();
```

- `BEFORE DELETE ON <tabla>`: el trigger corre **antes** de que el DELETE toque la tabla. Es la fase ideal para prohibir la operación.
- `FOR EACH ROW`: se ejecuta una vez por cada fila que intente borrar (si el DELETE afecta muchas filas, corre muchas veces).
- `EXECUTE FUNCTION`: vincula el trigger a la función definida arriba.
- Un mismo trigger/función se reutiliza en las dos tablas porque la regla es idéntica.

**¿Qué pasa si se saca este trigger?** Se puede volver a `DELETE` físico: un `DELETE FROM producto` borraría para siempre el producto y las líneas de `detalle_pedido` que lo referencian quedarían huérfanas o el `ON DELETE RESTRICT` lo impediría con un error menos claro. La baja lógica (R7) quedaría sin protección.

### Líneas 38-54 — función `fn_descontar_stock`

```sql
IF (SELECT stock FROM producto WHERE id = NEW.producto_id) < NEW.cantidad THEN
    RAISE EXCEPTION 'Stock insuficiente ...', NEW.producto_id, (SELECT stock...), NEW.cantidad;
END IF;

UPDATE producto
SET stock = stock - NEW.cantidad
WHERE id = NEW.producto_id;
```

- `NEW.producto_id`: `NEW` es la fila que se está insertando en `detalle_pedido`. `NEW.producto_id` es el producto que se está vendiendo.
- `(SELECT stock FROM producto WHERE id = NEW.producto_id)`: consulta el stock actual del producto. Si es **menor** que `NEW.cantidad`, se lanza excepción y el INSERT se rechaza (regla R5: stock nunca negativo).
- Si alcanza el stock, `UPDATE producto SET stock = stock - NEW.cantidad WHERE id = NEW.producto_id`: descuenta la cantidad vendida del stock.

**¿Qué pasa si se saca esta función?** El stock nunca se descontaría solo: dependería de que la aplicación "se acuerde" de actualizarlo. Y podría venderse más stock del que existe, porque el check (`stock >= 0` de la tabla `producto`) aún puede pasar si la app actualiza mal o no actualiza.

### Líneas 56-59 — trigger de stock

```sql
CREATE TRIGGER trg_detalle_descontar_stock
    BEFORE INSERT ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_descontar_stock();
```

- `BEFORE INSERT ON detalle_pedido`: se dispara al **insertar** una línea de detalle (cuando "se vende").
- Es `BEFORE` para poder **rechazar el INSERT** antes de que ocurra si no hay stock.

### Líneas 65-78 — función `fn_verificar_subtotal`

```sql
IF NEW.subtotal != (NEW.cantidad * NEW.precio_unitario) THEN
    RAISE EXCEPTION 'El subtotal (%) no coincide con cantidad (%) x precio_unitario (%). Resultado esperado: %', ...;
END IF;
```

- Verifica la coherencia interna del `detalle_pedido`: el `subtotal` guardado debe ser exactamente la multiplicación. Esto garantiza que nunca haya una línea con subtotal "inventado".
- Los `%` en el mensaje son placeholders que se completan con los argumentos.

### Líneas 80-83 — trigger de subtotal

```sql
CREATE TRIGGER trg_detalle_verificar_subtotal
    BEFORE INSERT OR UPDATE ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_verificar_subtotal();
```

- `BEFORE INSERT OR UPDATE`: valida tanto al insertar como al actualizar, porque el subtotal se puede dejar de calcular correctamente en cualquiera de las dos operaciones.

### Verificación (Parte 1)

Con `test_restricciones.sql` (sobre `copia_trabajo`, dentro de `BEGIN...ROLLBACK` con `SAVEPOINT`s):
- `DELETE FROM categoria` → **ERROR** "No esta permitido eliminar registros fisicamente..." (la regla lo bloqueó).
- `UPDATE categoria SET activo = FALSE` → OK, 1 fila (la baja lógica sí se permite).
- Insertar detalle de Muzzarella cantidad 3 con stock 10 → OK, stock quedó **7** (descontó).
- Insertar detalle de Coca-Cola cantidad 100 con stock 20 → **ERROR** "Stock insuficiente..."
- Insertar detalle con subtotal 9999 (debería ser 1000) → **ERROR** "El subtotal no coincide..."
- Insertar detalle con subtotal correcto → OK.

---

## 3. Parte 2 — concurrencia (informe_concurrencia.md)

La teoría dice que el nivel de aislamiento por defecto de PostgreSQL es **READ COMMITTED**, y que eso permite lecturas no repetibles y lecturas fantasma. La consigna pedía reproducirlas y verificar la explicación de la IA contra el motor real.

### Escenario 1 — Lectura no repetible

- Sesión A: `BEGIN; SET TRANSACTION ISOLATION LEVEL READ COMMITTED; SELECT stock ...` (devuelve 10).
- Sesión B: `UPDATE producto SET stock = 50; COMMIT;`
- Sesión A lee de nuevo: devuelve **50**.

**Explicación**: en READ COMMITTED cada lectura ve el último COMMIT vigente en ese instante. Como B commiteó entre las dos lecturas de A, A ve valores distintos.

**Verificación en el motor**: repetido con `REPEATABLE READ`, la segunda lectura devolvió **10** — no cambió, porque ese nivel toma un snapshot al inicio de la transacción. La IA acertó.

### Escenario 2 — Lectura fantasma

- Sesión A: `SELECT COUNT(*) FROM producto WHERE activo = TRUE;` → 1.
- Sesión B: inserta un producto nuevo activo y COMMIT.
- Sesión A cuenta de nuevo → **2**.

**Explicación**: una fila nueva que cumple el `WHERE` "aparece" en la segunda consulta. En READ COMMITTED no hay protección contra esto.

**Verificación en el motor**: repetido con `SERIALIZABLE`, el segundo COUNT devolvió **2** de nuevo (no vio el fantasma). La IA acertó.

### Escenario 3 — Espera por bloqueo

- Sesión A: `SELECT ... FOR UPDATE` sobre una fila (toma lock exclusivo, no hace COMMIT).
- Sesión B: mismo `FOR UPDATE` → **queda bloqueada esperando**.
- Sesión A: `ROLLBACK` → B se desbloquea y continúa.

**Explicación**: `FOR UPDATE` toma un lock exclusivo sobre las filas que coinciden con el WHERE; otra sesión no puede tomar el mismo lock y espera hasta que se libere con COMMIT o ROLLBACK. No es un error, es el mecanismo de exclusión mutua del motor.

**Verificación en el motor**: medido con cronómetro, la sesión B tardó ~3.4 segundos en completar el `FOR UPDATE` (esperó el ROLLBACK de A). El nivel de aislamiento no cambia este comportamiento. La IA acertó.

---

## 4. Parte 3 — lectura crítica (ejercicio_lectura_critica.md)

### Script 1: `UPDATE funcion SET activa = FALSE;`

- **Qué hace realmente**: pone `activa = FALSE` en **todas** las funciones. Sin `WHERE`, afecta a toda la tabla, incluso las de películas que siguen en cartel.
- **Por qué no cumple**: la consigna pide dar de baja solo funciones de películas retiradas.
- **Corregido**: agregar el `WHERE` que filtre por películas retiradas:
  ```sql
  UPDATE funcion
  SET activa = FALSE
  WHERE pelicula_id IN (SELECT id FROM pelicula WHERE retirada = TRUE);
  ```

### Script 2: `DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto);`

- **Qué hace realmente**: intenta borrar categorías sin productos, pero **falla con datos NULL**: si `categoria_id` contiene algún `NULL`, la subconsulta devuelve NULL y `NOT IN` con NULL retorna NULL (ni TRUE ni FALSE), por lo que esas filas **no se borran**. Dependiendo de los datos, no borra nada o borra de más.
- **Por qué no cumple**: la intención es correcta, pero `NOT IN` es inseguro con valores NULL.
- **Corregido**: usar `NOT EXISTS`, que no tiene problemas con NULL:
  ```sql
  DELETE FROM categoria c
  WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.categoria_id = c.id);
  ```
- (Verificado: en PostgreSQL, `NOT IN` sobre una subconsulta con NULL no selecciona ninguna fila.)

---

## 5. Protocolo de seguridad (por qué se hizo así)

- **Copia**: se creó `plantilla_base` (esquema limpio, intocable) y de ahí `copia_trabajo` con `createdb -T plantilla_base copia_trabajo`. Todo script se probó en `copia_trabajo`.
- **Transacción**: cada aplicación se hizo dentro de `BEGIN ... ROLLBACK` (y con `SAVEPOINT` para los tests, para que un error esperado no abortara el resto).
- **Respaldo**: antes de un cambio estructural se hace `pg_dump -Fc copia_trabajo`.

La lección de la Parte 3 es la misma que defiende el protocolo: los scripts de IA pueden tener sintaxis correcta y aun así borrar todo (`UPDATE funcion SET activa = FALSE` sin WHERE) o fallar silenciosamente (`NOT IN` con NULL). Por eso nunca se ejecuta un script sin leerlo línea por línea, sin probarlo en la copia y sin poder defender cada línea.