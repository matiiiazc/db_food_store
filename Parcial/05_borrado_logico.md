# Objetivo 9 — Borrado lógico (soft delete) y su impacto

Evidencia: `borrado_logico_prueba.sql` + `schema.sql` (columna `activo`) + `triggers_restricciones.sql` (trigger anti-DELETE) + `Parcial/objetos.sql` (view `vista_productos_vigentes`) + `TP5/indices.sql` (índice parcial).

## 1. Cómo está implementado

- **Columna `activo BOOLEAN NOT NULL DEFAULT TRUE`** en `categoria` y `producto` (regla R7 del enunciado: el negocio no elimina físicamente, conserva el historial).
- **Trigger `trg_categoria_no_delete` / `trg_producto_no_delete`** (función `fn_impedir_delete_logico`): un `DELETE` físico lanza `RAISE EXCEPTION`. La única forma de "dar de baja" es `UPDATE ... SET activo = FALSE`.

```sql
CREATE TRIGGER trg_producto_no_delete
    BEFORE DELETE ON producto
    FOR EACH ROW
    EXECUTE FUNCTION fn_impedir_delete_logico();
```

## 2. Impacto en consultas

- **Toda consulta de catálogo filtra por `activo`**:
  - `vista_productos_vigentes` (objetos.sql) usa `WHERE pr.activo AND c.activo`.
  - Los reportes de ventas NO filtran por `activo` (deben ver el histórico aunque el producto se haya desactivado): el soft delete no rompe los joins históricos.
- **Verificación:** con `UPDATE producto SET activo = FALSE` un producto deja de aparecer en la vista, pero sigue existiendo en la tabla y sus pedidos históricos se mantienen intactos (FK `ON DELETE RESTRICT`).

## 3. Impacto en índices

- El índice base `idx_producto_categoria_activo (categoria_id, activo)` (schema.sql) indexa la columna de baja lógica: listar productos vigentes de una categoría resuelve por índice.
- **Índice parcial `idx_producto_nombre_vig ... WHERE activo` (TP5):** solo indexa los productos activos. Es la aplicación directa del soft delete a la optimización: búsquedas por nombre sobre el catálogo vigente no tocan las filas inactivas.

```sql
CREATE INDEX idx_producto_nombre_vig
    ON producto (nombre text_pattern_ops)
    WHERE activo;
```

Impacto medido (informe_mediciones.md TP5): 20,0 → 8,4 ms en búsqueda por prefijo de nombre (Seq Scan a Bitmap Index Scan sobre el índice parcial).

## 4. Inconsistencias de diseño: `cliente` y `pedido` NO tienen baja lógica

A diferencia de `categoria`/`producto`, el esquema del TP1 no definió `activo` en `cliente` ni en `pedido`:
- `cliente` no se da de baja (el historial de compras debe seguir referenciándolo); el módulo de seguridad documenta que un cliente inactivo se maneja por negocio, no por esquema.
- `pedido` es inmutable a efectos de baja: confirma factura.
- Esto se documenta en `01_mer_relacional.md` (RQ del enunciado) y es coherente con la restricción de no eliminar físicamente el historial (R7).

## 5. Resultado demostrable (borrado_logico_prueba.sql)

1. `SELECT count(*) FROM producto` → 50.000.
2. `DELETE FROM producto WHERE id = 1;` → **ERROR**: no está permitido (trigger).
3. `UPDATE producto SET activo = FALSE WHERE id = 1;` → 1 fila (baja lógica correcta).
4. `SELECT count(*) FROM vista_productos_vigentes;` → 49.999 (el inactivo desaparece del catálogo).
5. Los pedidos del producto 1 siguen respondiendo en el histórico (join por `id`, sin filtro de activo).
6. ROLLBACK deja todo como estaba.