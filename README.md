# Food Store — Base de Datos II (Proyecto Integrador)

Sistema de gestión de pedidos para un negocio de comidas. Evolución por semanas (TP1→TP5) y entrega del parcial del TPI.

## Entregas

| Carpeta | Contenido |
|---|---|
| `schema.sql` | DDL base (TP1): modelo ER derivado a relacional, normalizado | 
| `TP2/` | Integridad, restricciones, transacciones y concurrencia (3 aislamientos, FOR UPDATE, 2 sesiones) |
| `TP3/` | Carga masiva (50k productos / 200k pedidos / 600k detalles) + optimización de reporting |
| `TP4/` | Consultas analíticas (joins ≥ 3 tablas, RANK), lectura crítica de planes, competencia (4387→2052 ms) |
| `TP5/` | Índices con medición antes/después, 3 vistas, vista materializada (2447→15 ms) |
| `Parcial/` | **Primera entrega del TPI**: los 9 objetivos, informe técnico y guía de defensa oral |

## Estructura

```
AGENTS.md            guía para agentes de IA y colaboradores
Parcial/             entrega del parcial (checklist, informes, scripts)
TP2/  TP3/  TP4/  TP5/
schema.sql           DDL base, fuente de Parcial/ddl.sql
```

Cada TP mantiene: scripts `.sql`, informes `.md`, evidencias `.html/.pdf` en `evidencias/`, y su DUIA (uso de IA).

## Resultados clave

- Facturación C1: 4387 → 2052 ms (**2,1×**) — índice de cobertura.
- Búsqueda cliente por apellido: 15,9 → 0,9 ms (**~18×**).
- Vista materializada facturación por categoría/mes: 2447 → ~15 ms (**~163×**).
- Borrado lógico y triggers de integridad verificados contra el motor real (PostgreSQL 18).

Ver `checklist_tpi.md` en `Parcial/` para el mapeo objetivo → evidencia.

## Documentación completa

- Informe técnico: `Parcial/06_informe_tecnico.md` (+ PDF `Parcial/informe_tecnico.pdf`).
- Guía de defensa oral: `Parcial/07_defensa_oral.md` (+ PDF `Parcial/defensa_oral.pdf`).