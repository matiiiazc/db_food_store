# Protocolo de Seguridad — Food Store

## 1. Copia

Nunca se trabaja sobre la base original. Se crea una copia de trabajo a partir de una plantilla intocable.

```powershell
# PostgreSQL 18 se instalo en: C:\Program Files\PostgreSQL\18\bin
# (agregar esa carpeta al PATH de Windows, o usar la ruta completa)

# Crear la plantilla (una sola vez)
createdb -U postgres plantilla_base
psql -U postgres -d plantilla_base -f schema.sql

# Crear la copia de trabajo
createdb -U postgres -T plantilla_base copia_trabajo
```

- `plantilla_base`: esquema limpio, no se modifica nunca.
- `copia_trabajo`: donde se ejecutan todos los scripts del día a día.
- Si la copia se rompe, se borra y se recrea con el mismo comando.

## 2. Transacción

Todo script que escribe (INSERT, UPDATE, DELETE, CREATE, ALTER, DROP) se ejecuta primero dentro de BEGIN/ROLLBACK para inspeccionar el efecto antes de confirmar.

```powershell
# Conectarse a la copia de trabajo
psql -U postgres -d copia_trabajo
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

```powershell
# Respaldo antes de cualquier cambio estructural
pg_dump -U postgres -Fc copia_trabajo > "respaldos\copia_trabajo_$(Get-Date -Format yyyyMMdd_HHmmss).dump"
```

Los respaldos se guardan en la carpeta `respaldos\` dentro del proyecto.

```powershell
# Para restaurar un respaldo
dropdb -U postgres copia_trabajo
createdb -U postgres -T plantilla_base copia_trabajo
pg_restore -U postgres -d copia_trabajo "respaldos\copia_trabajo_YYYYMMDD_HHMMSS.dump"
```
