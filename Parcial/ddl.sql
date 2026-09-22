-- ============================================================
-- FOOD STORE — schema.sql
-- TP1 - Base de Datos I - UTN
-- Tecnicatura Universitaria en Programación a Distancia
-- ============================================================
-- Descripción: DDL completo del esquema relacional de Food Store.
-- Crea el tipo enumerado para forma de pago y las cinco tablas
-- del sistema: categoria, cliente, producto, pedido y detalle_pedido.
-- ============================================================


-- ------------------------------------------------------------
-- TIPO ENUMERADO: forma de pago
-- Se usa CREATE TYPE ... AS ENUM para cerrar el dominio de
-- valores válidos. Solo se aceptan los tres medios de pago
-- que maneja el negocio actualmente.
-- ------------------------------------------------------------
CREATE TYPE forma_pago_enum AS ENUM (
    'EFECTIVO',
    'TARJETA',
    'TRANSFERENCIA'
);


-- ============================================================
-- TABLA: categoria
-- Representa las categorías de productos (ej: Pizzas, Bebidas).
-- R7: no se elimina físicamente; se marca activo = FALSE.
-- ============================================================
CREATE TABLE categoria (
    id         BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre     VARCHAR(80)  NOT NULL,
    activo     BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),

    -- R7: el nombre de categoría debe ser único
    CONSTRAINT uq_categoria_nombre UNIQUE (nombre)
);

-- Índice: listar productos vigentes de una categoría es una
-- consulta frecuente; filtrar por activo acelera ese acceso.
CREATE INDEX idx_categoria_activo ON categoria (activo);


-- ============================================================
-- TABLA: cliente
-- Representa a los clientes registrados en el sistema.
-- R6: el email identifica al cliente de forma única (clave
--     candidata alternativa). La PK es un id numérico para
--     no romper FK si el cliente cambia su email.
-- ============================================================
CREATE TABLE cliente (
    id         BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre     VARCHAR(100) NOT NULL,
    apellido   VARCHAR(100) NOT NULL,
    -- R6: clave candidata alternativa
    email      VARCHAR(254) NOT NULL,
    telefono   VARCHAR(20)  NULL,   -- atributo opcional razonable
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uq_cliente_email UNIQUE (email)
);


-- ============================================================
-- TABLA: producto
-- Representa los productos que vende el negocio.
-- R1: todo producto pertenece exactamente a una categoría (FK NOT NULL).
-- R5: precio y stock no pueden ser negativos (CHECK).
-- R7: baja lógica mediante campo activo.
-- ============================================================
CREATE TABLE producto (
    id           BIGINT          GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre       VARCHAR(150)    NOT NULL,
    descripcion  VARCHAR(300)    NULL,       -- atributo adicional razonable
    -- R5: precio no negativo; NUMERIC(10,2) evita errores de punto flotante
    precio       NUMERIC(10, 2)  NOT NULL,
    -- R5: stock no negativo
    stock        INTEGER         NOT NULL DEFAULT 0,
    -- R7: baja lógica
    activo       BOOLEAN         NOT NULL DEFAULT TRUE,
    -- R1: FK a categoria, NOT NULL porque la participación es total
    categoria_id BIGINT          NOT NULL,
    created_at   TIMESTAMPTZ     NOT NULL DEFAULT now(),

    -- R5: restricciones CHECK de reglas de negocio
    CONSTRAINT chk_producto_precio_positivo CHECK (precio >= 0),
    CONSTRAINT chk_producto_stock_positivo  CHECK (stock  >= 0),

    -- R1: integridad referencial hacia categoria
    -- ON DELETE RESTRICT: no se puede eliminar una categoría que tenga
    -- productos asociados; junto con R7 esto nunca debería ocurrir,
    -- pero lo dejamos como red de seguridad.
    CONSTRAINT fk_producto_categoria
        FOREIGN KEY (categoria_id)
        REFERENCES categoria (id)
        ON DELETE RESTRICT
);

-- Índice: consulta habitual = listar productos activos de una categoría.
CREATE INDEX idx_producto_categoria_activo ON producto (categoria_id, activo);


-- ============================================================
-- TABLA: pedido
-- Representa cada pedido realizado por un cliente.
-- R2: todo pedido pertenece exactamente a un cliente (FK NOT NULL).
-- ============================================================
CREATE TABLE pedido (
    id         BIGINT           GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha      TIMESTAMPTZ      NOT NULL DEFAULT now(),
    forma_pago forma_pago_enum  NOT NULL,
    -- R2: FK a cliente, NOT NULL porque la participación es total
    cliente_id BIGINT           NOT NULL,
    created_at TIMESTAMPTZ      NOT NULL DEFAULT now(),

    -- R2: integridad referencial hacia cliente
    -- ON DELETE RESTRICT: no se puede eliminar un cliente que tenga
    -- pedidos registrados; preserva el historial de facturación.
    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (cliente_id)
        REFERENCES cliente (id)
        ON DELETE RESTRICT
);

-- Índice: buscar todos los pedidos de un cliente es la consulta
-- más frecuente sobre esta tabla (ej: historial de un cliente).
CREATE INDEX idx_pedido_cliente ON pedido (cliente_id);


-- ============================================================
-- TABLA: detalle_pedido
-- Entidad asociativa que resuelve la relación N:M entre pedido
-- y producto (R3). Almacena los atributos propios de la relación:
-- cantidad y precio_unitario (R4).
-- R4: precio_unitario se guarda en el momento de la venta para
--     que un cambio posterior en producto.precio no altere
--     pedidos ya facturados.
-- ============================================================
CREATE TABLE detalle_pedido (
    -- Clave sustituta (surrogate key): se elige sobre la clave
    -- compuesta (pedido_id, producto_id) para simplificar
    -- referencias externas futuras y evitar FK compuestas.
    id              BIGINT         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- R3: FK a pedido, NOT NULL (participación total)
    pedido_id       BIGINT         NOT NULL,
    -- R3: FK a producto, NOT NULL (participación total)
    producto_id     BIGINT         NOT NULL,

    -- R4: unidades pedidas; debe ser al menos 1
    cantidad        INTEGER        NOT NULL,
    -- R4: precio al momento de la venta; no puede ser negativo
    precio_unitario NUMERIC(10, 2) NOT NULL,
    -- Subtotal almacenado por trazabilidad histórica: aunque es
    -- calculable como cantidad × precio_unitario, guardarlo evita
    -- que un cambio de precio futuro altere el valor ya facturado.
    subtotal        NUMERIC(12, 2) NOT NULL,

    -- Restricciones CHECK (R4 / R5)
    CONSTRAINT chk_detalle_cantidad_positiva
        CHECK (cantidad > 0),
    CONSTRAINT chk_detalle_precio_positivo
        CHECK (precio_unitario >= 0),
    CONSTRAINT chk_detalle_subtotal_positivo
        CHECK (subtotal >= 0),

    -- Un mismo producto no puede repetirse más de una vez
    -- dentro de un mismo pedido.
    CONSTRAINT uq_detalle_pedido_producto UNIQUE (pedido_id, producto_id),

    -- R3: integridad referencial hacia pedido
    -- ON DELETE RESTRICT: no se puede borrar un pedido que ya
    -- tiene líneas de detalle asociadas.
    CONSTRAINT fk_detalle_pedido
        FOREIGN KEY (pedido_id)
        REFERENCES pedido (id)
        ON DELETE RESTRICT,

    -- R3: integridad referencial hacia producto
    -- ON DELETE RESTRICT: no se puede borrar un producto que
    -- aparece en algún detalle; junto con R7 esto nunca debería
    -- ocurrir, pero protege la integridad del historial.
    CONSTRAINT fk_detalle_producto
        FOREIGN KEY (producto_id)
        REFERENCES producto (id)
        ON DELETE RESTRICT
);

-- Índice: consulta habitual = ver todas las líneas de un pedido.
CREATE INDEX idx_detalle_pedido ON detalle_pedido (pedido_id);

-- Índice: consulta habitual = ver en qué pedidos apareció un producto.
CREATE INDEX idx_detalle_producto ON detalle_pedido (producto_id);


