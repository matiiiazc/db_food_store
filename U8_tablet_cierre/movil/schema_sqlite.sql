-- Food Store - Tablet (SQLite) - schema_sqlite.sql (Consigna 1.b)
-- La tablet solo consulta y arma borradores: precio, stock y ventas los decide PostgreSQL.
PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS cola_sync;
DROP TABLE IF EXISTS item_borrador;
DROP TABLE IF EXISTS pedido_borrador;
DROP TABLE IF EXISTS producto_cache;
-- tabla auxiliar para importación de instantánea (Consigna 2.a)
DROP TABLE IF EXISTS snapshot_servidor;

-- Catálogo replicado desde el servidor (instantánea). Fuente de verdad: PostgreSQL.
CREATE TABLE producto_cache (
    id              INTEGER PRIMARY KEY,          -- id de producto en PostgreSQL
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto     INTEGER NOT NULL CHECK (stock_visto >= 0),
    disponible      INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado       INTEGER NOT NULL CHECK (eliminado IN (0, 1)),
    fecha_copia     TEXT    NOT NULL              -- ISO-8601 de la instantánea
) STRICT;

-- Borrador armado en la tablet (no es una venta confirmada)
CREATE TABLE pedido_borrador (
    id_local   TEXT PRIMARY KEY,                  -- UUID
    usuario    TEXT NOT NULL,                     -- identificador inventado del vendedor (sin datos reales)
    forma_pago TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO','TARJETA','TRANSFERENCIA')),
    fecha      TEXT NOT NULL                      -- ISO-8601
) STRICT;

-- Ítems del borrador (referencian el borrador y el producto del caché)
CREATE TABLE item_borrador (
    id           INTEGER PRIMARY KEY,             -- rowid local del ítem
    id_local     TEXT    NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    producto_id  INTEGER NOT NULL REFERENCES producto_cache(id),
    cantidad     INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0)
) STRICT;

-- Cola de sincronización / semáforo (el móvil propone, el servidor dispone)
CREATE TABLE cola_sync (
    solicitud_uuid TEXT PRIMARY KEY,              -- UUID idempotente de la solicitud
    id_local       TEXT NOT NULL REFERENCES pedido_borrador(id_local),
    estado         TEXT NOT NULL CHECK (estado IN ('PENDIENTE','CONFLICTO','RECHAZADO','SIMULADO_APROBADO')),
    motivo         TEXT
) STRICT;
