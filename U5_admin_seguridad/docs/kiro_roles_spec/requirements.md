# Kiro Spec — Roles y permisos de mínimo privilegio (Food Store)

> Planificación asistida por Kiro (plantilla; Kiro no está instalado en este
> entorno, la spec se redactó a mano con su plantilla — constancia en
> BITACORA.md). Corresponde a la Parte A del TP de la Unidad 5.

## Requirements

### Contexto
Food Store necesita dejar de operar con el superusuario para tareas de rutina.
Cada rol del sistema debe permitir exactamente lo que su función necesita y
nada más (principio de mínimo privilegio). Se trabaja sobre `food_store_tp3`
(PostgreSQL 18), esquema `public`.

### Historial de usuario (roles)
| Rol | Necesito poder… | Para poder… |
|---|---|---|
| `rol_app_lectura` | leer catálogo y transacciones | que la aplicación consulte sin romper datos |
| `rol_app_escritura` | insertar/actualizar pedidos y detalle, ajustar stock/precio/activo de producto | registrar ventas y cambios de inventario operativo |
| `rol_soporte` | ver y editar datos de cuenta de usuario (salvo credenciales) | atender incidencias de identidades |
| `rol_reportes` | leer tablas y vistas de reporte | alimentar el panel sin tocar el origen |
| `app_web` (login) | actuar como la escritura | que el servicio web opere con su propia identidad |
| `admin_datos` (login) | lo de soporte + reportes | administrar datos y soportar cuentas |
| `soporte_app` (login) | lo de soporte | identidad humana del área de soporte |
| `reportes_app` (login) | lo de reportes | identidad humana del área de reportes |

### Requerimientos funcionales
1. **RF-1** — Los roles de grupo no deben poder iniciar sesión (NOLOGIN).
2. **RF-2** — Ningún rol debe poder borrar filas de las tablas del dominio: la
   baja es lógica (columna `activo`/`eliminado` del proyecto).
3. **RF-3** — Las identidades (`usuario`) no deben exponer `email` ni
   `password_hash` a los roles transaccionales; el acceso a cuentas debe ser
   de soporte y a **nivel de columna**.
4. **RF-4** — El escalamiento de privilegios (otorgar membresía de rol) debe
   estar reservado a un rol administrador; los logins operativos no deben
   tener `ADMIN OPTION` sobre ninguna membresía.
5. **RF-5** — Las tablas y funciones futuras del esquema `public` deben
   heredar la misma política (ALTER DEFAULT PRIVILEGES).
6. **RF-6** — La autenticación debe quedar registrada (tabla `audit_login`).

### Criterios de aceptación (verificables)
- CA-1: `\du` muestra los 4 grupos con *Cannot login* y 4 logins.
- CA-2: `information_schema.role_table_grants` lista SELECT para lectura y
  reportes y INSERT/UPDATE (solo pedido/detalle) para escritura.
- CA-3: `has_column_privilege('rol_app_escritura','producto','nombre','UPDATE') = false`
  y `…'stock','UPDATE' = true` (permiso por columna).
- CA-4: `has_column_privilege('rol_soporte','usuario','email','SELECT') = false`.
- CA-5: `GRANT admin_datos TO app_web` ejecutado como `app_web` falla
  (permiso denegado).

## Design

### Decisiones
1. **4 roles de grupo + 4 logins.** Los logins no acumulan privilegios
   propios: heredan por membresía. Corresponde al modelo de identidades de la
   Clase 1.
2. **Permiso a nivel de columna donde el dato es sensible.** `usuario.email` y
   `usuario.password_hash` quedan fuera del alcance de soporte; la rotación de
   contraseña pasa por `fn_resetear_password` (SECURITY DEFINER), nunca por
   `UPDATE` directo.
3. **Escritura con grano de columna sobre `producto`** (`stock, precio, activo`):
   la app puede modificar inventario pero no renombrar/reclasificar productos.
4. **Sin `DELETE`**: coerencia con la baja lógica del proyecto (R7).
5. **`REVOKE ALL ON usuario FROM PUBLIC`** + default privileges explícitos:
   el grano mínimo se mantiene para objetos futuros.

### Modelo resultante (resumen)
```
rol_app_lectura  NOLOGIN                    -> SELECT dominio (no usuario)
rol_app_escritura NOLOGIN (miembro lectura) -> INSERT/UPDATE pedido y detalle;
                                               UPDATE (stock,precio,activo) producto
rol_soporte      NOLOGIN (miembro lectura)  -> SELECT/UPDATE col seleccionadas de usuario;
                                               EXECUTE fn_resetear_password
rol_reportes     NOLOGIN (miembro lectura)  -> SELECT dominio + vistas + MV de top categorias
app_web          LOGIN (miembro escritura)
admin_datos      LOGIN (miembro soporte+reportes)
soporte_app      LOGIN (miembro soporte)
reportes_app     LOGIN (miembro reportes)
```