# Ejercicio de Lectura Crítica — Food Store

## Script 1

```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartel
UPDATE funcion
SET activa = FALSE;
```

### Qué haría realmente tal como está escrito

Este script pone `activa = FALSE` en **todas** las filas de la tabla `funcion`, sin importar si la película está retirada de cartel o no. El `UPDATE` no tiene `WHERE`, así que afecta cada fila de la tabla.

### Por qué no coincide con la consigna

La consigna dice "dar de baja **las funciones de películas retiradas de cartel**", es decir, solo las funciones cuya película esté retirada. El script tal como está escrito desactiva funciones de películas que siguen en cartel, lo cual es un error grave: una película que sigue en cartel dejaría de tener funciones activas.

### Versión corregida

```sql
-- Dar de baja SOLO las funciones de películas retiradas de cartel
UPDATE funcion
SET activa = FALSE
WHERE pelicula_id IN (
    SELECT id FROM pelicula WHERE retirada = TRUE
);
```

O alternativamente con JOIN:

```sql
UPDATE funcion f
SET activa = FALSE
FROM pelicula p
WHERE f.pelicula_id = p.id
  AND p.retirada = TRUE;
```

---

## Script 2

```sql
-- Generado para: limpiar las categorías sin productos asociados
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

### Qué haría realmente tal como está escrito

El script borra categorías cuyo `id` no aparezca en la columna `categoria_id` de `producto`. **Pero** hay un problema: si `categoria_id` tiene valores `NULL`, la subconsulta devuelve `NULL`, y en SQL `NULL NOT IN (...)` retorna `NULL` (no `TRUE`), así que esas filas **no se borran**. Dependiendo de los datos, esto puede funcionar parcialmente o no funcionar como se espera.

### Por qué no coincide con la consigna

La consigna dice "limpiar las categorías sin productos asociados". La intención es correcta, pero la implementación tiene un defecto conocido con `NOT IN` cuando la subconsulta contiene `NULL`. Si algún producto tiene `categoria_id = NULL`, la condición `NOT IN` deja de evaluar a `TRUE` para esas filas, y la categoría no se borra aunque no tenga productos.

### Versión corregida

Usando `NOT EXISTS` (más seguro, ignora `NULL`):

```sql
DELETE FROM categoria c
WHERE NOT EXISTS (
    SELECT 1 FROM producto p WHERE p.categoria_id = c.id
);
```

O usando `NOT IN` con filtro de `NULL` (equivalente cuando la subconsulta se excluye de NULLs):

```sql
DELETE FROM categoria c
WHERE c.id NOT IN (
    SELECT categoria_id FROM producto WHERE categoria_id IS NOT NULL
);
```

> **Nota:** se eliminó una versión anterior con `DELETE ... USING producto p WHERE c.id = p.categoria_id AND p.id IS NULL`. Era **contradictoria**: el `USING` une solo las categorías que **tienen** productos (`c.id = p.categoria_id`), y la condición `p.id IS NULL` nunca podía cumplirse porque `p.id` es la clave primaria (nunca NULL). Por eso ese DELETE nunca borraba nada; es el tipo de error silencioso que se corrige al leer línea por línea. La opción preferida es `NOT EXISTS`, porque es clara, eficiente y no tiene problemas con valores `NULL`.
