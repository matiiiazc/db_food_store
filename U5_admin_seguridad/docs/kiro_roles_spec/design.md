# Kiro Spec — Design: roles, grants y objetos de identidad

> Parte de `docs/kiro_roles_spec/`. Detalla el SQL de `sql/roles.sql` con la
> justificación de cada decisión. Se redactó con la plantilla de especificación
> de Kiro (requirements en `requirements.md`).

## 1. Objetos de identidad (reconstrucción de la Clase 2)

- `usuario` se evolucionó a tabla de identidades: `id, nombre, rol, email,
  password_hash, fecha_alta, activo`. Los registros maestros del caso
  mayorista (801-803) se conservan; se agregaron identidades del sistema
  (101-108) con roles funcionales variados y fechas de alta distribuidas.
- `audit_login(tiempo, email, exito, origen)`: registro de cada intento de
  autenticación (base de la rendición de cuentas).
- `fn_autenticar(email, password) -> boolean`: SECURITY DEFINER, compara con
  `crypt`/`gen_salt` (pgcrypto) y registra el intento en `audit_login`.
- `fn_resetear_password(email, password) -> boolean`: SECURITY DEFINER,
  reservada a soporte; permite rotar el hash sin `UPDATE` directo.

## 2. Roles y membresías

```
CREATE ROLE rol_app_lectura  NOLOGIN;
CREATE ROLE rol_app_escritura NOLOGIN;
CREATE ROLE rol_soporte       NOLOGIN;
CREATE ROLE rol_reportes      NOLOGIN;
CREATE ROLE app_web       LOGIN PASSWORD '...';
CREATE ROLE admin_datos   LOGIN PASSWORD '...';
CREATE ROLE soporte_app   LOGIN PASSWORD '...';
CREATE ROLE reportes_app  LOGIN PASSWORD '...';

GRANT rol_app_lectura  TO rol_app_escritura, rol_soporte, rol_reportes;
GRANT rol_soporte, rol_reportes TO admin_datos;
GRANT rol_app_escritura TO app_web;
GRANT rol_soporte TO soporte_app;
GRANT rol_reportes TO reportes_app;
```

Ninguna membresía usa `WITH ADMIN OPTION`: los logins no pueden otorgar a
terceros la pertenencia a un rol (CA-5).

## 3. Grants (mínimo privilegio)

| Destinatario | Objeto | Operación | Justificación |
|---|---|---|---|
| `rol_app_lectura` | tablas dominio | SELECT | lectura transaccional |
| `rol_app_escritura` | pedido, detalle_pedido | INSERT, UPDATE | registrar/ajustar ventas |
| `rol_app_escritura` | producto (columnas stock, precio, activo) | UPDATE | inventario operativo, sin renombrar |
| `rol_soporte` | usuario (id, nombre, rol, fecha_alta, activo) | SELECT | ver cuentas sin exponer credenciales |
| `rol_soporte` | usuario (nombre, activo) | UPDATE | ajustes de cuenta puntuales |
| `rol_reportes` | dominio + vistas + MV | SELECT | alimentar reportes |
| `rol_app_lectura` | fn_autenticar | EXECUTE | login desde la app |
| `rol_soporte` | fn_resetear_password | EXECUTE | rotación gestionada |

## 4. Defensa en profundidad

- `GRANT USAGE ON SCHEMA public` a los 4 roles de grupo.
- `REVOKE ALL ON usuario FROM PUBLIC` y sobre `audit_login`.
- `ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public`:
  - SELECT a los 3 roles de lectura/reporte/soporte;
  - INSERT/UPDATE/DELETE a escritura (para sus nuevas tablas);
  - EXECUTE a lectura/soporte/reportes.
- Verificación integral en `docs/verificacion_permisos_du.txt`:
  `\du`, `role_table_grants`, `role_column_grants`, `has_table_privilege`,
  `has_column_privilege` y prueba negativa (SET ROLE + acceso a columna
  prohibida → `permiso denegado`).