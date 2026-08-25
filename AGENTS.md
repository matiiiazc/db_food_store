# AGENTS.md — Food Store

## Descripción del proyecto
Repositorio de scripts SQL para el TP1 de Base de Datos I (UTN - Tecnicatura Universitaria en Programación a Distancia).

Contiene el esquema relacional completo de un sistema de gestión de pedidos de una food store.

## Archivos
- `schema.sql` — DDL completo: tipo enumerado `forma_pago_enum` y cinco tablas (`categoria`, `cliente`, `producto`, `pedido`, `detalle_pedido`) con PK, FK, CHECK, UNIQUE e índices.

## Stack
- PostgreSQL (usa `GENERATED ALWAYS AS IDENTITY`, `TIMESTAMPTZ`, `CREATE TYPE ... AS ENUM`)

## Reglas de negocio documentadas en el script
- **R1**: Todo producto pertenece a exactamente una categoría (FK NOT NULL).
- **R2**: Todo pedido pertenece a exactamente un cliente (FK NOT NULL).
- **R3**: Relación N:M pedido ↔ producto resuelta por `detalle_pedido`.
- **R4**: `precio_unitario` se almacena al momento de la venta (snapshot histórico).
- **R5**: `precio` y `stock` no pueden ser negativos (CHECK).
- **R6**: Email del cliente es único (clave candidata alternativa).
- **R7**: Baja lógica en `categoria` y `producto` mediante campo `activo`.

## Comandos útiles
```bash
# Conectar a PostgreSQL y crear el esquema
psql -U usuario -d base_datos -f schema.sql
```

## Convenciones
- El archivo `schema.sql` contiene comments detallados justificando cada decisión de diseño.
- No se usa `CASCADE` en DELETE; se prefiere `RESTRICT` para proteger la integridad referencial.
