-- ============================================================================
-- U5 - Parte D | usuario_anon.sql
-- Proteccion de datos personales: tabla anonimizada de identidades.
--
-- Criterio (el mismo de la Clase 2): mapeo DETERMINISTA a valores
-- sinteticos. Un mismo usuario SIEMPRE produce el mismo valor anonimo, por
-- lo que las agregaciones sobre usuario_anon son comparables a las de usuario.
-- No se conserva ningun dato identificable: no hay email real, ni
-- password_hash real, ni nombre real.
-- ============================================================================
DROP TABLE IF EXISTS usuario_anon;

CREATE TABLE usuario_anon AS
SELECT id                                    AS usuario_id,
       'usr' || id::text || '@anon.local'    AS email_anon,
       'usuario_' || id::text                AS nombre_anon,
       rol                                   AS rol,
       fecha_alta                            AS fecha_alta,
       'anon'                                AS password_hash_anon
FROM usuario;

-- Lectura para reportes (coherente con la politica de la Parte A).
GRANT SELECT ON usuario_anon TO rol_reportes;

\echo '== muestra (datos sinteticos, deterministas) =='
SELECT usuario_id, email_anon, nombre_anon, rol, fecha_alta, password_hash_anon
FROM usuario_anon
ORDER BY usuario_id
LIMIT 8;