# spec: indice_descartado_producto_categoria

Objetivo (propuesta de IA, luego descartada): acelerar la consulta de productos por categoría.

Consulta afectada (propuesta):
```sql
SELECT id, nombre, precio
FROM producto
WHERE categoria_id = 1;
```

Propuesta recibida de la IA: crear `CREATE INDEX idx_producto_categoria ON producto (categoria_id);`

**Decisión: DESCARTADO por sobreindexación.**

Justificación:
1. **Índice redundante con uno ya existente.** Ya existe `idx_producto_categoria_activo (categoria_id, activo)` (creado en la Semana 3), que subsumee cualquier consulta por `categoria_id` con o sin vigencia. Crear `idx_producto_categoria` sería duplicar cobertura sin ganar nada.
2. **Costo de mantenimiento sin beneficio.** Agregar un índice más sobre `producto` encarece cada INSERT/UPDATE (dos índices que mantener para el mismo acceso), sin que el plan cambie: la consulta ya se resuelve por `idx_producto_categoria_activo`.
3. Regla de la cátedra: solo se acepta un índice que se justifique; esta propuesta no mejora ningún plan ni lectura ni escritura.

Métrica verificada: con el índice existente, la consulta por `categoria_id` ya usa `Bitmap Index Scan` sobre `idx_producto_categoria_activo` (0 lectura Seq).

Criterio: no se aplica.