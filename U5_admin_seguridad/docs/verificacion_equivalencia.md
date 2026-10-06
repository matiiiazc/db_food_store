# Verificación de equivalencia anonimizada (Parte D)

## Tabla generada

`schema`: `usuario_anon(usuario_id, email_anon, nombre_anon, rol, fecha_alta, password_hash_anon)`.

- Mapeo **determinista**: el mismo usuario siempre produce el mismo valor
  sintético (`usr<id>@anon.local`, `usuario_<id>`, `password_hash='anon'`).
- No queda ningún dato personal identificable de origen.

## Consulta pedida (especificada a la IA)

Agregación: **cantidad de usuarios por rol y por mes de alta**.

Consulta sobre `usuario_anon`:

```sql
SELECT rol, to_char(date_trunc('month', fecha_alta)::date, 'YYYY-MM') AS mes, count(*) AS n
FROM usuario_anon GROUP BY 1, 2 ORDER BY 1, 2;
```

Consulta equivalente sobre `usuario` (la real):

```sql
SELECT rol, to_char(date_trunc('month', fecha_alta)::date, 'YYYY-MM') AS mes, count(*) AS n
FROM usuario GROUP BY 1, 2 ORDER BY 1, 2;
```

## Resultados lado a lado

| rol                 | mes     | n (usuario real) | n (usuario_anon) |
|---------------------|---------|------------------|------------------|
| administrador       | 2025-01 | 1                | 1                |
| administrador       | 2025-11 | 1                | 1                |
| aplicacion          | 2025-01 | 1                | 1                |
| aplicacion          | 2025-12 | 1                | 1                |
| aplicacion          | 2026-01 | 1                | 1                |
| reportes            | 2025-02 | 1                | 1                |
| responsable_control | 2025-03 | 1                | 1                |
| responsable_control | 2025-05 | 1                | 1                |
| responsable_control | 2025-07 | 1                | 1                |
| soporte             | 2025-02 | 1                | 1                |
| tienda              | 2025-11 | 1                | 1                |

**11 filas, idénticas en ambos lados.**

## Comprobación de equivalencia (no solo afirmada)

```sql
-- tuplas en la real que no aparecen en la anon:       0
SELECT count(*) FROM (
  SELECT rol, to_char(date_trunc('month',fecha_alta)::date,'YYYY-MM'), count(*)
  FROM usuario GROUP BY 1,2
  EXCEPT
  SELECT rol, to_char(date_trunc('month',fecha_alta)::date,'YYYY-MM'), count(*)
  FROM usuario_anon GROUP BY 1,2
) x;

-- tuplas en la anon que no aparecen en la real:       0
-- (misma consulta invertida)
```

Ambos `EXCEPT` devuelven **0 filas**: la anonimización conserva exactamente
el perfil agregado del conjunto (mismos roles, mismos meses, mismos conteos).

## Qué información de Food Store no debería salir hacia una IA sin anonimizar

Los datos personales de los clientes y del personal (nombre, apellido, email,
teléfono, y el historial de pedidos que permita atribuir consumo a una
persona) y sobre todo las credenciales y hashes de contraseña de las
identidades del sistema. También los datos locales de operación que puedan
identificar la infraestructura (rutas, IPs internas, usuarios de motor). Todo
eso debe pasar por el criterio determinista de `usuario_anon` (u otra
técnica de anonimización verificada por equivalencia) antes de usarse como
insumo de una herramienta de IA.