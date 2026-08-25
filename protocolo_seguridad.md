# Protocolo de Seguridad — Food Store

## 1. Copia

Nunca se trabaja sobre la base original. Se crea una copia de trabajo a partir de una plantilla intocable.

```bash
# Crear la plantilla (una sola vez)
createdb plantilla_base
psql -d plantilla_base -f schema.sql

# Crear la copia de trabajo
createdb -T plantilla_base copia_trabajo
```

- `plantilla_base`: esquema limpio, no se modifica nunca.
- `copia_trabajo`: donde se ejecutan todos los scripts del día a día.
- Si la copia se rompe, se borra y se recrea con el mismo comando.

## 2. Transacción

Todo script que escribe (INSERT, UPDATE, DELETE, CREATE, ALTER, DROP) se ejecuta primero dentro de BEGIN/ROLLBACK para inspeccionar el efecto antes de confirmar.

```bash
psql -d copia_trabajo
```

```sql
BEGIN;

-- script aquí (restricciones, inserts, modificaciones)

-- inspeccionar efecto
SELECT * FROM categoria;

-- si todo está bien:
COMMIT;
-- o si hay errores:
ROLLBACK;
```

Regla: siempre empezar con ROLLBACK hasta estar seguro.

## 3. Respaldo

Antes de cualquier cambio estructural (ALTER, DROP, CREATE TRIGGER, etc.), se exporta la copia de trabajo para poder volver atrás sin depender del ROLLBACK.

```bash
pg_dump -Fc copia_trabajo > respaldos/copia_trabajo_$(date +%Y%m%d_%H%M%S).dump
```

Los respaldos se guardan en la carpeta `respaldos/` dentro del proyecto.

```bash
# Para restaurar un respaldo
dropdb copia_trabajo
createdb -T plantilla_base copia_trabajo
pg_restore -d copia_trabajo respaldos/copia_trabajo_YYYYMMDD_HHMMSS.dump
```
