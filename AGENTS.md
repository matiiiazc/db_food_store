# AGENTS.md — Food Store (Proyecto Integrador)

Repositorio del **Trabajo Práctico Integrador** de Base de Datos II (UTN — Tecnicatura Universitaria en Programación a Distancia). Proyecto «Food Store»: sistema de gestión de pedidos para un negocio de comidas, evolucionando semana a semana.

Cada Trabajo Práctico (TP1–TP5) dejó sus entregables en su carpeta. La construcción final de la primera entrega del TPI está en `Parcial/`.

## Estructura del repositorio

```
AGENTS.md              <- este archivo
README.md              <- índice general y guía de uso
schema.sql             <- DDL base (TP1): ENUM forma_pago_enum + 5 tablas
TP2/                   <- Semana 2: integridad, restricciones, concurrencia
  restricciones.sql    <- triggers/funciones de integridad
  test_restricciones.sql
  informe_concurrencia.md    <- 3 aislamientos + FOR UPDATE (2 sesiones)
  protocolo_seguridad.md     <- copy -> transacción -> respaldo
  ejercicio_lectura_critica.md, defensa_oral.md, DUIA_parte{1,2,3}.md
  TP2_Laboratorio_Concurrencia_IA.pdf, tp2.zip
  evidencias/          <- TP2_evidencias.{html,pdf}
TP3/                   <- Semana 3: carga masiva + optimizaciones
TP4/                   <- Semana 4: consultas analíticas + competencia
  evidencias/
TP5/                   <- Semana 5: índices, vistas, vista materializada
  specs/               <- spec por objeto (formato Kiro)
Parcial/               <- PRIMERA ENTREGA TPI (obj 1–9 del checklist)
  checklist_tpi.md     <- mapa objetivo → evidencia
  01_mer_relacional.md / 02_normalizacion.md / 03_dml_consultas.md
  04_transacciones.md / 05_borrado_logico.md
  06_informe_tecnico.md (.html/.pdf) / 07_defensa_oral.md (.html/.pdf)
  ddl.sql / consultas.sql / objetos.sql / triggers_restricciones.sql
  transacciones_prueba.sql / borrado_logico_prueba.sql
```

## Stack
- PostgreSQL 18 (usa `IDENTITY`, `TIMESTAMPTZ`, `ENUM`, `PL/pgSQL`, triggers, materialized views, `CALL`).
- IA: OpenCode (motor primario). Kiro: requerido por cátedra pero **no instalado** en esta máquina.

## Base de datos
- Esquema: `schema.sql` (5 tablas + ENUM). Base de datos real de trabajo: `food_store_tp3` (masiva: 50.000 productos, 20.000 clientes, 200.000 pedidos, 600.000 detalles).

## Reglas de negocio (R1–R7, del TP1)
- **R1** producto → 1 categoría (FK NOT NULL) · **R2** pedido → 1 cliente (FK NOT NULL) · **R3** N:M pedido–producto vía `detalle_pedido` · **R4** `precio_unitario` snapshot al momento de la venta · **R5** `precio`/`stock` ≥ 0 (CHECK) · **R6** email único · **R7** baja lógica con `activo` en `categoria` y `producto`.

## Comandos útiles
```bash
# Crear esquema sobre una base limpia
psql -U postgres -d food_store_tp3 -f schema.sql
# Cargar la ENTREGA del parcial (objetos, triggers, demos)
psql -U postgres -d food_store_tp3 -f Parcial/objetos.sql
```

## Convenciones
- Comentarios en SQL: solo el número de ejercicio (consigna de la cátedra).
- Todo script de escritura se ejecuta primero dentro de `BEGIN...ROLLBACK` (protocolo de cátedra).
- Verificar cualquier afirmación en el motor real (`EXPLAIN ANALYZE`, salidas reales) antes de documentarla.