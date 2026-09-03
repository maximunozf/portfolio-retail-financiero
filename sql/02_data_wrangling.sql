-- ==============================================================================
-- FASE 1: DIAGNÓSTICO Y PERFILAMIENTO DE DATOS (DATA PROFILING)
-- Objetivo: Auditar las 6 tablas de la Capa Bronce para detectar anomalías,
-- nulos, textos vacíos y validar rangos lógicos antes de la transformación.
-- ==============================================================================

USE retail_financiero;

-- 1. Auditoría: TABLA LOCALES
SELECT 
    'locales' AS tabla,
    COUNT(*) AS total_registros,
    SUM(CASE WHEN id_local IS NULL THEN 1 ELSE 0 END) AS nulos_id,
    SUM(CASE WHEN nombre_local IS NULL THEN 1 ELSE 0 END) AS nulos_nombre,
    SUM(CASE WHEN region IS NULL THEN 1 ELSE 0 END) AS nulos_region,
    SUM(CASE WHEN nombre_local LIKE ' %' OR nombre_local LIKE '% ' THEN 1 ELSE 0 END) AS espacios_nombre,
    SUM(CASE WHEN region LIKE ' %' OR region LIKE '% ' THEN 1 ELSE 0 END) AS espacios_region
FROM locales;

-- 2. Auditoría: TABLA PRODUCTOS
SELECT 
    'productos' AS tabla,
    COUNT(*) AS total_registros,
    SUM(CASE WHEN id_producto IS NULL THEN 1 ELSE 0 END) AS nulos_id,
    SUM(CASE WHEN costo_compra IS NULL THEN 1 ELSE 0 END) AS nulos_costo,
    SUM(CASE WHEN precio_venta IS NULL THEN 1 ELSE 0 END) AS nulos_precio_venta,
    SUM(CASE WHEN categoria IS NULL THEN 1 ELSE 0 END) AS nulos_categoria,
    SUM(CASE WHEN nombre_producto IS NULL THEN 1 ELSE 0 END) AS nulos_nombre,
    SUM(CASE WHEN categoria LIKE ' %' OR categoria LIKE '% ' THEN 1 ELSE 0 END) AS espacios_categoria,
    SUM(CASE WHEN nombre_producto LIKE ' %' OR nombre_producto LIKE '% ' THEN 1 ELSE 0 END) AS espacios_nombre,
    MIN(costo_compra) AS costo_min_detectado, 
    MIN(precio_venta) AS precio_venta_min_detectado,
    MAX(costo_compra) AS costo_max_detectado,
    MAX(precio_venta) AS precio_venta_max_detectado
FROM productos;

-- 3. Auditoría: TABLA INVENTARIO
SELECT 
    'inventario' AS tabla,
    COUNT(*) AS total_registros,
    SUM(CASE WHEN id_inventario IS NULL THEN 1 ELSE 0 END) AS nulos_id_inven,
    SUM(CASE WHEN id_local IS NULL THEN 1 ELSE 0 END) AS nulos_id_local,
    SUM(CASE WHEN id_producto IS NULL THEN 1 ELSE 0 END) AS nulos_id_produc,
    SUM(CASE WHEN stock_disponible IS NULL THEN 1 ELSE 0 END) AS nulos_stock,
    MIN(stock_disponible) AS stock_min_detectado, 
    MAX(stock_disponible) AS stock_max_detectado  
FROM inventario;

-- 4. Auditoría: TABLA DETALLE_TRANSACCIONES
SELECT
	'detalle_transacciones' AS tabla,
    COUNT(*) AS total_registros,
	SUM(CASE WHEN id_detalle IS null THEN 1 ELSE 0 END) AS nulos_id_detalle,
    SUM(CASE WHEN id_transaccion IS null THEN 1 ELSE 0 END) AS nulos_id_transaccion,
    SUM(CASE WHEN id_producto IS null THEN 1 ELSE 0 END) AS nulos_id_producto,
    SUM(CASE WHEN cantidad IS null THEN 1 ELSE 0 END) AS nulos_cantidad,
    SUM(CASE WHEN subtotal IS null THEN 1 ELSE 0 END) AS nulos_subtotal,
    MIN(cantidad) AS min_cantidad,
    MAX(cantidad) AS max_cantidad,
    MIN(subtotal) AS min_subtotal,
    MAX(subtotal) AS max_subtotal
FROM detalle_transacciones;

-- 5. Auditoría: TABLA CLIENTES_CREDITO (Evidencia de datos sucios)
SELECT 
    'clientes_credito' AS tabla,
    COUNT(*) AS total_registros,
    SUM(CASE WHEN id_cliente IS null THEN 1 ELSE 0 END) AS nulos_id_cliente,
    SUM(CASE WHEN nombre_completo LIKE ' %' OR nombre_completo LIKE '% ' THEN 1 ELSE 0 END) AS nombres_con_espacios,
    SUM(CASE WHEN nombre_completo IS null THEN 1 ELSE 0 END) AS nulos_nombre_completo,
    SUM(CASE WHEN fecha_nacimiento IS null THEN 1 ELSE 0 END) AS nulos_fecha_nacimiento, -- solo buscamos nulos ya que el tipo de dato de fecha_nacimiento es date
    SUM(CASE WHEN TRIM(limite_credito) = '' THEN 1 ELSE 0 END) AS limite_credito_vacios,
    SUM(CASE WHEN limite_credito LIKE ' %' OR limite_credito LIKE '% ' THEN 1 ELSE 0 END) AS limite_credito_con_espacios,
    SUM(CASE WHEN limite_credito IS null THEN 1 ELSE 0 END) AS nulos_limite_credito,
    SUM(CASE WHEN deuda_actual IS null THEN 1 ELSE 0 END) AS nulos_deuda_actual,
    SUM(CASE WHEN estado_riesgo LIKE ' %' OR estado_riesgo LIKE '% ' THEN 1 ELSE 0 END) AS estados_con_espacios,
    SUM(CASE WHEN estado_riesgo IS null THEN 1 ELSE 0 END) AS nulos_estado_riesgo,
    MIN(deuda_actual) AS min_deuda_actual,
    MAX(deuda_actual) AS max_deuda_actual,
    MIN(fecha_nacimiento) AS min_fecha_nace,
    MAX(fecha_nacimiento) AS max_fecha_nace
FROM clientes_credito;

-- 6. Auditoría: TABLA TRANSACCIONES (Evidencia de datos sucios)
SELECT
	'transacciones' AS tabla,
    COUNT(*) AS total_registros,
    SUM(CASE WHEN id_transaccion IS null THEN 1 ELSE 0 END) AS nulos_id_transaccion,
    SUM(CASE WHEN id_local IS null THEN 1 ELSE 0 END) AS nulos_id_local,
    SUM(CASE WHEN id_cliente IS null THEN 1 ELSE 0 END) AS nulos_id_cliente,
    SUM(CASE WHEN fecha_venta IS null THEN 1 ELSE 0 END) AS nulos_fecha_venta,
    SUM(CASE WHEN fecha_venta NOT REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN 1 ELSE 0 END) AS fechas_formato_incorrecto, -- buscamos formatos incorrectos de fecha ya que el tipo de dato es varchar
    SUM(CASE WHEN monto_total IS null THEN 1 ELSE 0 END) AS nulos_monto_total,
    SUM(CASE WHEN tipo_pago IS null THEN 1 ELSE 0 END) AS nulos_tipo_pago,
    SUM(CASE WHEN tipo_pago LIKE ' %' OR tipo_pago LIKE '% ' THEN 1 ELSE 0 END) AS espacios_tipo_pago,
    SUM(CASE WHEN cantidad_cuotas IS null THEN 1 ELSE 0 END) AS nulos_cantidad_cuotas,
    MIN(monto_total) AS min_monto_total,
    MAX(monto_total) AS max_monto_total,
    MIN(cantidad_cuotas) AS min_cantidad_cuotas,
    MAX(cantidad_cuotas) AS max_cantidad_cuotas
FROM transacciones;

-- ==============================================================================
-- FASE 2: LIMPIEZA Y ESTANDARIZACIÓN (CAPA PLATA)
-- Objetivo: Construir Vistas (Views) para encapsular las reglas de limpieza 
-- sobre las tablas que presentaron datos corruptos en el Data Profiling.
-- Justificación: Las tablas locales, productos, inventario y detalle_transacciones 
-- mantienen integridad estructural, por lo que no requieren vistas de limpieza.
-- ==============================================================================

-- 2.1 Vista Limpia: Clientes Crédito
-- Soluciona: Espacios en textos (TRIM) y convierte vacíos absolutos a NULL.
-- Transforma el límite de crédito de texto (VARCHAR) a numérico financiero (DECIMAL).
--
-- POR QUÉ EL LÍMITE AUSENTE QUEDA EN NULL Y NO EN 0.00:
-- 119 clientes (5,95%) no tienen límite de crédito registrado. Convertirlos a
-- cero los dejaba dentro del denominador de la tasa de utilización de crédito
-- con límite 0 pero con deuda > 0, lo que SOBRESTIMABA la utilización en unos
-- 3 puntos porcentuales (ej.: cartera CASTIGADA marcaba 52,3% en vez de 49,2%).
-- Un NULL propagado es honesto: "no sabemos su límite" no es lo mismo que
-- "su límite es cero". Los KPI que dividen por el límite declaran esa base.
CREATE VIEW vw_clientes_credito_limpios AS
SELECT
	id_cliente,
    TRIM(nombre_completo) AS nombre_completo,
    fecha_nacimiento,
    CAST(NULLIF(TRIM(limite_credito), '') AS DECIMAL(15,2)) AS limite_credito,
    deuda_actual,
    UPPER(TRIM(estado_riesgo)) AS estado_riesgo
FROM clientes_credito;

-- ==============================================================================
-- 2.2 Vista Limpia: Transacciones
-- Soluciona:
-- Estandarización de fechas mutantes (VARCHAR) a formato universal matemático (DATE).
-- Limpieza de espacios basura, corrección ortográfica y unificación a mayúsculas en métodos de pago.
--
-- POR QUÉ SE AGREGÓ EL CUARTO FORMATO ('18 mayo 25'):
-- La versión anterior sólo parseaba los 3 formatos numéricos y mandaba el resto
-- a NULL. Eran 550 transacciones (11,0%) por $825.880.963 (11,1% de la
-- facturación) que el KPI mensual descartaba mientras los KPI 1, 2 y 3 sí las
-- contaban: dos totales distintos en el mismo informe, sin declararlo.
--
-- POR QUÉ SE MAPEA EL MES A MANO Y NO SE USA STR_TO_DATE(..., '%d %M %y'):
-- '%M' depende de la variable de sesión lc_time_names del servidor MySQL, que
-- por defecto viene en inglés. El mapeo explícito da el mismo resultado en
-- cualquier instalación, sin configuración previa.
--
-- POR QUÉ SE CONSERVA formato_fecha_origen:
-- Es trazabilidad. Permite responder "¿de qué formato venía este registro?" y
-- aislar el subconjunto en texto sin tener que volver a la tabla cruda.
-- ==============================================================================

CREATE VIEW vw_transacciones_limpias AS
SELECT
    id_transaccion,
    id_local,
    id_cliente,
    -- De texto a DATE
    CASE
        WHEN fecha_venta REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$' THEN STR_TO_DATE(fecha_venta, '%d/%m/%Y')
        WHEN fecha_venta REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN STR_TO_DATE(fecha_venta, '%d-%m-%Y')
        WHEN fecha_venta REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN STR_TO_DATE(fecha_venta, '%Y-%m-%d')
        WHEN fecha_venta REGEXP '^[0-9]{1,2} [a-zA-Z]+ [0-9]{2}$' THEN
            STR_TO_DATE(
                CONCAT(
                    SUBSTRING_INDEX(fecha_venta, ' ', 1), '-',
                    CASE LOWER(SUBSTRING_INDEX(SUBSTRING_INDEX(fecha_venta, ' ', 2), ' ', -1))
                        WHEN 'enero'      THEN '01'
                        WHEN 'febrero'    THEN '02'
                        WHEN 'marzo'      THEN '03'
                        WHEN 'abril'      THEN '04'
                        WHEN 'mayo'       THEN '05'
                        WHEN 'junio'      THEN '06'
                        WHEN 'julio'      THEN '07'
                        WHEN 'agosto'     THEN '08'
                        WHEN 'septiembre' THEN '09'
                        WHEN 'octubre'    THEN '10'
                        WHEN 'noviembre'  THEN '11'
                        WHEN 'diciembre'  THEN '12'
                    END, '-',
                    SUBSTRING_INDEX(fecha_venta, ' ', -1)
                ), '%d-%m-%y')
        ELSE NULL
    END AS fecha_venta,
    -- Trazabilidad del origen: de qué formato venía cada fecha.
    CASE
        WHEN fecha_venta REGEXP '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'   THEN 'ISO'
        WHEN fecha_venta REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$'   THEN 'DD/MM/AAAA'
        WHEN fecha_venta REGEXP '^[0-9]{2}-[0-9]{2}-[0-9]{4}$'   THEN 'DD-MM-AAAA'
        WHEN fecha_venta REGEXP '^[0-9]{1,2} [a-zA-Z]+ [0-9]{2}$' THEN 'TEXTO'
        ELSE 'NO_RECONOCIDO'
    END AS formato_fecha_origen,
    monto_total,
            CASE 
    			WHEN UPPER(TRIM(tipo_pago)) = 'EFECTIVO' THEN 'EFECTIVO'
    			WHEN UPPER(TRIM(tipo_pago)) = 'DEBITO' THEN 'DEBITO'
                WHEN UPPER(TRIM(tipo_pago)) = 'CREDITO' THEN 'CREDITO'
    			WHEN UPPER(TRIM(tipo_pago)) = 'CREDITO TIENDA' THEN 'CREDITO'
    			ELSE 'OTROS / POR CLASIFICAR'
            END AS tipo_pago,
    cantidad_cuotas
FROM transacciones;
