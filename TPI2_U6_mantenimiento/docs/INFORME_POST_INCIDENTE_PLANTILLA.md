# INFORME POST-INCIDENTE - U6 (Simulacro de desastre)

> Plantilla. **No completar con valores inventados.** Usar datos medidos durante la ejecución del simulacro (tiempos, logs, salidas de verificaciones). Adjuntar evidencias (dump utilizado, logs, salidas `.txt`).

## 1. Identificación
- **Evento:** Simulacro de desastre (restauración desde último respaldo verificado)
- **Fecha/hora inicio:** [YYYY-MM-DD HH:MM:SS]
- **Fecha/hora fin:** [YYYY-MM-DD HH:MM:SS]
- **Responsable/equipo:** [completar]
- **Entorno:** PostgreSQL 16+/18 (clúster local/entorno de pruebas). **Base origen NO afectada:** `food_store_tp3`

## 2. Causa / Alcance del simulacro
- **Escenario simulado:** [describir brevemente]
- **Respaldo utilizado:** Ruta del `.dump` + directorio `backup_*` + hash SHA256 (ver `*.sha256` y `verificar_backup.ps1` resultado)
- **Destino restauración:** Base **nueva y separada** (ej. `food_store_tp3_restore_sim_<TS>`) — **diferente** a la base protegida.

## 3. Tiempos (contra reloj)
| Medición | Valor (ms) | Valor (s) | Origen del dato |
|---|---|---|---|
| Tiempo total del simulacro | [medido] | [medido] | `simulacro_desastre_*.log` / cronómetro |
| Tiempo de restauración (flujo restore) | [medido] | [medido] | `simulacro_desastre_*.log` / salida del script |
| Otras (verificaciones) | [medido/opcional] | [medido/opcional] | logs/salidas |

## 4. Evidencias generadas
- Backup verificado: `[ruta dump + .list.txt + .sha256]`
- Log simulacro: `[simulacro_desastre_<TS>.log]`
- Log restore: `[restore_*_<TS>.log]`
- Verificación post-restore: `[verif_post_restore_sim_<TS>.txt]`
- Comparación origen (solo lectura, si ejecutada): `[compare_origen_sim_<TS>.txt]`
- Informe generado por script: `[INFORME_POST_INCIDENTE_<TS>.md]`

## 5. Verificación post-restauración (completar con datos reales)
| Ítem | Resultado (OK/NO/NA) | Evidencia (ruta/sección) | Observaciones |
|---|---|---|---|
| Base restaurada creada y accesible | [ ] | log restore | [completar] |
| Conteos tablas clave coinciden con origen (o justificación) | [ ] | verif_post_restore vs compare_origen | [completar] |
| Baja lógica (`activo`/`eliminado`) coherente | [ ] | salidas SQL | [completar] |
| PK/FK/CHECK/UNIQUE presentes | [ ] | catálogo | [completar] |
| Vistas/MV/funciones/procedimientos/triggers/índices | [ ] | catálogo | [completar] |
| `forma_pago_enum` (EFECTIVO,TARJETA,TRANSFERENCIA) | [ ] | catálogo/ENUM | [completar] |
| Chequeos integridad (orfandad/incoherencia) → 0 filas | [ ] | sección [12]/verificacion_integridad | [completar o justificar] |
| Origen `food_store_tp3` sin modificaciones | [ ] | verificación (no usado como destino) | [completar] |

## 6. Comportamiento ante restauración desfasada (tablets/offline)
- [ ] Aplicable al escenario evaluado. Resultado/conclusión: [completar según U8 / evidencia]
- Nota: `SIMULADO_APROBADO` no es venta; operaciones deben revalidarse (`RECHAZADO/CONFLICTO`).

## 7. Conclusión, lecciones aprendidas y acciones correctivas
- **Conclusión:** [completar con hechos, sin afirmaciones globales no verificadas]
- **Lecciones aprendidas:** [completar]
- **Acciones correctivas / mejoras:** [completar]
- **Estado final:** [CONFORME / CON DESVÍOS / NO CONFORME] — justificado con evidencias

## 8. Anexos
- Logs completos, salidas de verificaciones, hash del dump utilizado, versión de PostgreSQL.
