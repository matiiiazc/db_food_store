-- ============================================================================
-- TP6 (Unidad 4) | 00_setup_ambiente.sql - preparacion idempotente
-- Prepara la copia poblada de Food Store para la Parte 1 y Parte 2:
--   1. Maestras de la extension mayorista: lote, deposito, usuario
--   2. Baja logica (columna eliminado) en pedido y detalle_pedido, exigida
--      por la consulta del reporte del panel (el proyecto ya la usa en
--      producto/categoria, regla R7)
--   3. Seed de pedidos de HOY (400) para que el EXPLAIN ANALYZE del reporte
--      devuelva filas; pasa por los triggers reales de la base
--      (trg_detalle_descontar_stock, trg_detalle_verificar_subtotal).
--
-- Idempotente: se puede volver a ejecutar sin duplicar datos.
-- ============================================================================

CREATE TABLE IF NOT EXISTS lote (
    id BIGINT PRIMARY KEY,
    proveedor TEXT NOT NULL,
    fecha_recepcion DATE NOT NULL
);

CREATE TABLE IF NOT EXISTS deposito (
    id BIGINT PRIMARY KEY,
    nombre TEXT NOT NULL,
    ubicacion TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS usuario (
    id BIGINT PRIMARY KEY,
    nombre TEXT NOT NULL,
    rol TEXT NOT NULL
);

INSERT INTO deposito (id, nombre, ubicacion) VALUES
    (30, 'Deposito Central', 'Av. Siempre Viva 742'),
    (31, 'Deposito Norte',   'Ruta 9 km 52')
ON CONFLICT (id) DO NOTHING;

INSERT INTO lote (id, proveedor, fecha_recepcion) VALUES
    (501, 'Proveedor Harinas SA',     DATE '2026-10-01'),
    (502, 'Proveedor Harinas SA',     DATE '2026-10-03'),
    (503, 'Proveedor Congelados Sur', DATE '2026-10-05')
ON CONFLICT (id) DO NOTHING;

INSERT INTO usuario (id, nombre, rol) VALUES
    (801, 'Ana Contreras', 'responsable_control'),
    (802, 'Bruno Sosa',    'responsable_control'),
    (803, 'Carla Mendez',  'responsable_control')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE pedido         ADD COLUMN IF NOT EXISTS eliminado BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE detalle_pedido ADD COLUMN IF NOT EXISTS eliminado BOOLEAN NOT NULL DEFAULT FALSE;

-- ----------------------------------------------------------------------------
-- Seed de pedidos de HOY (solo si no hay ninguno).
-- Se eligen productos con stock >= cantidad para respetar
-- trg_detalle_descontar_stock, y el subtotal se calcula como
-- cantidad * precio para pasar la validacion de subtotal.
-- ----------------------------------------------------------------------------
DO $$
DECLARE
    v_hoy    TIMESTAMPTZ := date_trunc('day', now());
    v_ped    BIGINT;
    v_prod   BIGINT;
    v_cant   INTEGER;
    v_precio NUMERIC(10,2);
    v_i      INTEGER;
    v_n      INTEGER;
    v_j      INTEGER;
    v_fp     forma_pago_enum;
    v_fps    forma_pago_enum[] :=
        ARRAY['EFECTIVO'::forma_pago_enum,'TARJETA'::forma_pago_enum,'TRANSFERENCIA'::forma_pago_enum];
BEGIN
    IF (SELECT count(*) FROM pedido WHERE fecha >= v_hoy AND fecha < v_hoy + interval '1 day') > 0 THEN
        RAISE NOTICE 'Ya existen pedidos de hoy; no se siembra nada.';
        RETURN;
    END IF;

    FOR v_i IN 1..400 LOOP
        v_fp := v_fps[1 + (random()*2)::int];
        INSERT INTO pedido (fecha, forma_pago, cliente_id)
        VALUES (v_hoy + (random() * interval '23 hours 59 minutes'), v_fp,
                (1 + (random()*20000)::int)::BIGINT)
        RETURNING id INTO v_ped;

        v_n := 1 + (random()*4)::int;
        FOR v_j IN 1..v_n LOOP
            v_cant := 1 + (random()*4)::int;
            SELECT p.id, p.precio INTO v_prod, v_precio
              FROM producto p
             WHERE p.stock >= v_cant
             ORDER BY random()
             LIMIT 1;
            IF v_prod IS NULL THEN
                RAISE EXCEPTION 'No quedan productos con stock para sembrar (escenario degradado)';
            END IF;
            INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario, subtotal)
            VALUES (v_ped, v_prod, v_cant, v_precio, v_cant * v_precio);
        END LOOP;
    END LOOP;

    RAISE NOTICE 'Seed OK: 400 pedidos del dia generados.';
END $$;