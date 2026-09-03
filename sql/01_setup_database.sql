-- ==============================================================================
-- PROYECTO: RETAIL FINANCIERO & LOGÍSTICA
-- ARCHIVO: 01_setup_database.sql
-- OBJETIVO: Creación de la base de datos e integración de datos
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS retail_financiero
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE retail_financiero;

-- ==============================================================================
-- 1. TABLAS DE DIMENSIONES (Independientes)
-- ==============================================================================

CREATE TABLE locales (
    id_local INT PRIMARY KEY,
    nombre_local VARCHAR(100),
    region VARCHAR(100)
);

-- POR QUÉ limite_credito ENTRA COMO VARCHAR Y NO COMO DECIMAL:
-- el 5,95% de los clientes llega sin límite informado (celda vacía). Cargarlo
-- como DECIMAL haría que MySQL lo convirtiera silenciosamente a 0 en la
-- ingesta, y un 0 inventado en el denominador distorsiona la utilización de
-- crédito. Se recibe tal cual viene y la decisión se toma explícitamente en la
-- capa de limpieza (02_data_wrangling.sql), donde queda documentada.
CREATE TABLE clientes_credito (
    id_cliente INT PRIMARY KEY,
    nombre_completo VARCHAR(150),
    fecha_nacimiento DATE,
    limite_credito VARCHAR(50),
    deuda_actual DECIMAL(10,2),
    estado_riesgo VARCHAR(50)
);

-- ==============================================================================
-- INYECCIÓN POR DEFECTO: CLIENTE ANÓNIMO (Metodología Kimball)
-- Evita nulos en la tabla de hechos para mantener la integridad financiera
-- y asegurar que las ventas sin id_cliente registrado no rompan el sistema.
-- ==============================================================================
INSERT INTO clientes_credito (
    id_cliente, 
    nombre_completo, 
    fecha_nacimiento, 
    limite_credito, 
    deuda_actual, 
    estado_riesgo
) 
VALUES (
    9999, 
    'CLIENTE ANONIMO', 
    '1900-01-01', 
    '0.00', 
    0.00, 
    'SIN RIESGO'
)
ON DUPLICATE KEY UPDATE id_cliente=id_cliente;

CREATE TABLE productos (
    id_producto INT PRIMARY KEY,
    categoria VARCHAR(100),
    nombre_producto VARCHAR(150),
    costo_compra DECIMAL(10,2),  
    precio_venta DECIMAL(10,2)   
);

-- ==============================================================================
-- 2. TABLAS DE HECHOS (Dependientes)
-- ==============================================================================

CREATE TABLE inventario (
    id_inventario INT PRIMARY KEY,
    id_local INT,
    id_producto INT,
    stock_disponible INT,
    FOREIGN KEY (id_local) REFERENCES locales(id_local),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

CREATE TABLE transacciones (
    id_transaccion INT PRIMARY KEY,
    id_local INT,
    id_cliente INT, 
    fecha_venta VARCHAR(50), 
    monto_total DECIMAL(10,2),
    tipo_pago VARCHAR(50),       -- 'Debito', 'Efectivo', 'Credito Tienda'
    cantidad_cuotas INT,        
    FOREIGN KEY (id_local) REFERENCES locales(id_local),
    FOREIGN KEY (id_cliente) REFERENCES clientes_credito(id_cliente)
);

CREATE TABLE detalle_transacciones (
    id_detalle INT PRIMARY KEY,
    id_transaccion INT,
    id_producto INT,
    cantidad INT,
    subtotal DECIMAL(10,2), 
    FOREIGN KEY (id_transaccion) REFERENCES transacciones(id_transaccion),
    FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

-- ==============================================================================
-- 3. INGESTA DE LOS CSV
--
-- ORDEN OBLIGATORIO (las claves foráneas lo exigen):
--   1) locales      2) clientes_credito   3) productos
--   4) inventario   5) transacciones      6) detalle_transacciones
--
-- OPCIÓN A — phpMyAdmin (la que se usó en este proyecto, XAMPP en Windows):
--   1. Seleccionar la base retail_financiero en el panel izquierdo.
--   2. Clic en la tabla de destino y luego en la pestaña 'Importar'.
--   3. 'Seleccionar archivo' → el CSV correspondiente de data/.
--   4. Formato: 'CSV'.  Columnas separadas por: ,   Entrecomilladas por: "
--   5. Marcar 'La primera línea del archivo contiene los nombres de columna'.
--   6. 'Continuar'. Repetir con la siguiente tabla, en el orden de arriba.
--
-- OPCIÓN B — LOAD DATA INFILE (requiere local_infile=1 y que los CSV estén en
-- la carpeta que indique secure_file_priv; por eso quedó comentada).
-- ==============================================================================
-- LOAD DATA INFILE './data/locales.csv' INTO TABLE locales FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
-- LOAD DATA INFILE './data/clientes_credito.csv' INTO TABLE clientes_credito FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
-- LOAD DATA INFILE './data/productos.csv' INTO TABLE productos FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
-- LOAD DATA INFILE './data/inventario.csv' INTO TABLE inventario FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
-- LOAD DATA INFILE './data/transacciones.csv' INTO TABLE transacciones FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
-- LOAD DATA INFILE './data/detalle_transacciones.csv' INTO TABLE detalle_transacciones FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\n' IGNORE 1 ROWS;
