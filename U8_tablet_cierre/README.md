# TP8 — Food Store en la feria (Unidad 8)

**Repositorio:** https://github.com/matiiiazc/db_food_store · **Integrantes:** *(completar)*

Base de la tablet en **SQLite** + simulación de sincronización (semáforo) contra **PostgreSQL** + cierre de la capa de datos. La tablet **solo consulta y arma borradores**: precio, stock y ventas los decide PostgreSQL (`SIMULADO_APROBADO` no es una venta). Todo con datos inventados, sin credenciales reales. **Evidencias:** salidas de ejecución reales (`movil/evidencia_*.txt`).

## Estructura
- `movil/schema_sqlite.sql` — esquema SQLite (FK ON, 4 tablas STRICT).
- `movil/pruebas_sqlite.sql` — 1.c (COMMIT/ROLLBACK, C1, C7).
- `movil/semaforo.sql` — semáforo (PENDIENTE vs snapshot).
- `movil/servidor_snapshot.csv` — instantánea exportada de `v_snapshot_movil`.
- `movil/foodstore_movil.db` — base SQLite resultante.
- `movil/evidencia_pruebas_sqlite.txt`, `evidencia_casos.txt`, `evidencia_pg_antes.txt`, `evidencia_pg_despues.txt` — evidencias de ejecución.
- `docs/informe.pdf` — 1.a, 2.c, 3.a–c (<=6 págs).
- `docs/kiro/{requirements.md,design.md,tasks.md}` — spec (EARS) y tareas.
- `docs/bitacora_ia.md`, `docs/DUIA.md`.

## Orden para crear todo desde cero

Requisitos: **PostgreSQL 16+** (base `food_store_tp3` del proyecto, copia de trabajo) y **SQLite 3.37+** (o Python 3 con `sqlite3`, usado aquí: 3.50.4).

### 1) PostgreSQL — vista e instantánea (Consigna 2.a)
En `psql` sobre la base de trabajo (ajustar usuario/ruta):
```sql
-- crear la vista (lee producto: mapeo activo/stock -> disponible, eliminado; precio a centavos)
CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT id, nombre,
       (ROUND(precio * 100))::bigint AS precio_centavos,
       stock,
       (CASE WHEN activo AND stock > 0 THEN 1 ELSE 0 END)::int AS disponible,
       (CASE WHEN activo THEN 0 ELSE 1 END)::int AS eliminado
FROM producto;

-- exportar (reemplazar por la ruta absoluta de salida)
\copy (SELECT * FROM v_snapshot_movil ORDER BY id) TO '.../movil/servidor_snapshot.csv' CSV HEADER
```
> Registrar el conteo de pedidos/stock **antes** (evidencia «PG no cambió»): `SELECT count(*) FROM pedido; SELECT count(*) FROM detalle_pedido;` y un muestreo de `producto`.

### 2) SQLite — esquema + snapshot + pruebas (Consignas 1.b, 1.c, 2.a)
Crear la base e importar la instantánea (ejemplo con Python `sqlite3`, reproduce `movil/foodstore_movil.db`):
```bash
# desde la carpeta U8_tablet_cierre (o ajustando rutas)
python -c "
import sqlite3,csv,os
base='movil'; db=os.path.join(base,'foodstore_movil.db')
con=sqlite3.connect(db); cur=con.cursor()
cur.executescript(open(os.path.join(base,'schema_sqlite.sql'),encoding='utf-8').read())
FECHA='2026-11-05T12:00:00Z'
with open(os.path.join(base,'servidor_snapshot.csv'),newline='',encoding='utf-8') as f:
    rows=[(int(x['id']),x['nombre'],int(x['precio_centavos']),int(x['stock']),int(x['disponible']),int(x['eliminado'])) for x in csv.DictReader(f)]
cur.executemany('INSERT INTO snapshot_servidor VALUES (?,?,?,?,?,?)', rows)
cur.executemany('INSERT INTO producto_cache (id,nombre,precio_centavos,stock_visto,disponible,eliminado,fecha_copia) VALUES (?,?,?,?,?,?,?)', [(a,b,c,d,e,f,FECHA) for (a,b,c,d,e,f) in rows])
con.commit(); con.close(); print('ok',len(rows),'fecha_copia',FECHA)
"
```
Luego ejecutar las pruebas (COMMIT/ROLLBACK, C1, C7) y el semáforo/casos: correr `movil/pruebas_sqlite.sql` (y/o el runner de evidencia) y aplicar `movil/semaforo.sql` tras preparar cada caso C2–C6 (ver `movil/evidencia_casos.txt` para los comandos/resultados exactos). `PRAGMA foreign_keys=ON` debe estar activo.

### 3) Verificación «PostgreSQL no cambió» (Consigna 2.c)
Repetir en PostgreSQL los conteos/muestreo del paso 1 y comparar con `evidencia_pg_antes.txt` (deben ser idénticos).

## Notas
- `SIMULADO_APROBADO` **no** confirma una venta ni modifica el servidor.
- Casos C2–C6: los «cambios en la copia del servidor» se simulan sobre `snapshot_servidor`/nuevas instantáneas en SQLite (sin tocar PostgreSQL). Ver `evidencia_casos.txt`.
- Defensa (semana 13): mapa, un caso en vivo y un hallazgo de IA (10 min).