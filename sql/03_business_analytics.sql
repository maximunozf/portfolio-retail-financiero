-- ==============================================================================================
-- PROYECTO: Retail y Finanzas
-- ARCHIVO: 03_business_analytics.sql
-- AUTOR: Maximiliano Muñoz Fuentes
-- OBJETIVO:
--   Extraer KPIs críticos de negocio con las vistas ya creadas.
--   Focos de análisis: Calidad de Datos, Rendimiento Comercial, Comportamiento
--   de Pago, Riesgo Crediticio, Inventario y Segmentación.
--
-- REGLA DEL PROYECTO: toda cifra publicada declara su base de cálculo
-- (universo, período y exclusiones). Cuando un KPI no usa las 5.000
-- transacciones, lo dice en su encabezado.
--
-- USE retail_financiero;  -- descomentar si el cliente SQL no tiene la BD activa
-- ==============================================================================================

-- ==============================================================================================
-- BLOQUE 0: CALIDAD DE DATOS
-- Objetivo: cuantificar los defectos del origen ANTES de analizar, porque son
-- los que determinan qué universo puede usar cada KPI.
-- ==============================================================================================
-- ----------------------------------------------------------------------------------------------
-- KPI 0.1: Peso del cliente anónimo (id 9999) en la facturación
-- Pregunta de Negocio: ¿Cuánta venta no podemos atribuir a un cliente real?
-- Por qué importa: el id 9999 se inserta en 01_setup_database.sql para que las
-- ventas sin cliente no rompan la integridad referencial (metodología Kimball).
-- Es correcto para la tabla de hechos, pero NO es un cliente: si entra a los
-- rankings de cartera, encabeza todos los tops y deforma la segmentación.
-- ----------------------------------------------------------------------------------------------
SELECT
    COUNT(*) AS transacciones_totales,
    SUM(CASE WHEN id_cliente = 9999 THEN 1 ELSE 0 END) AS transacciones_sin_cliente,
    ROUND(100.0 * SUM(CASE WHEN id_cliente = 9999 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_transacciones,
    SUM(monto_total) AS facturacion_total,
    SUM(CASE WHEN id_cliente = 9999 THEN monto_total ELSE 0 END) AS facturacion_sin_cliente,
    ROUND(100.0 * SUM(CASE WHEN id_cliente = 9999 THEN monto_total ELSE 0 END) / SUM(monto_total), 2) AS pct_facturacion
FROM vw_transacciones_limpias;

-- ----------------------------------------------------------------------------------------------
-- KPI 0.2: Formatos de fecha en el origen
-- Pregunta de Negocio: ¿Qué parte de la serie temporal depende del parseo?
-- ----------------------------------------------------------------------------------------------
SELECT
    formato_fecha_origen,
    COUNT(*) AS transacciones,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_transacciones,
    SUM(monto_total) AS facturacion,
    SUM(CASE WHEN fecha_venta IS NULL THEN 1 ELSE 0 END) AS no_parseadas
FROM vw_transacciones_limpias
GROUP BY formato_fecha_origen
ORDER BY transacciones DESC;

-- ----------------------------------------------------------------------------------------------
-- KPI 0.3: Cobertura del límite de crédito
-- Pregunta de Negocio: ¿Sobre cuántos clientes podemos calcular utilización de crédito?
-- ----------------------------------------------------------------------------------------------
SELECT
    COUNT(*) AS clientes_totales,
    SUM(CASE WHEN limite_credito IS NULL THEN 1 ELSE 0 END) AS clientes_sin_limite,
    ROUND(100.0 * SUM(CASE WHEN limite_credito IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_sin_limite
FROM vw_clientes_credito_limpios
WHERE id_cliente <> 9999;

-- ==============================================================================================
-- BLOQUE 1: RENDIMIENTO COMERCIAL
-- Base: las 5.000 transacciones del dataset.
-- ==============================================================================================
-- ----------------------------------------------------------------------------------------------
-- KPI 1: Ranking de Facturación por Sucursal (Top Locales)
-- Pregunta de Negocio: ¿Cuáles son las sucursales que generan el mayor volumen de ingresos?
-- ----------------------------------------------------------------------------------------------
  SELECT
	l.id_local,
	l.nombre_local,
    COUNT(v.id_transaccion) AS total_transacciones,
    SUM(v.monto_total) AS suma_total_local
FROM locales AS l
JOIN vw_transacciones_limpias AS v ON l.id_local=v.id_local
GROUP BY l.id_local, l.nombre_local
ORDER BY suma_total_local DESC;

-- ----------------------------------------------------------------------------------------------
-- KPI 2: Distribución por Método de Pago
-- Pregunta de Negocio: ¿Qué métodos de pago generan el mayor volumen transaccional y financiero?
-- ----------------------------------------------------------------------------------------------
SELECT
	t.tipo_pago,
	COUNT(t.id_transaccion)AS total_transacciones,
    SUM(t.monto_total) AS suma_total
FROM vw_transacciones_limpias AS t
GROUP BY t.tipo_pago
ORDER BY suma_total DESC;

-- ----------------------------------------------------------------------------------------------
-- KPI 3: Exposición de Deuda por Nivel de Riesgo
-- Pregunta de Negocio: ¿Cuánto capital tenemos en riesgo según el estado de nuestros deudores?
-- ----------------------------------------------------------------------------------------------
-- Nota: el alias se escribe en minúscula de forma consistente. Los alias de
-- tabla son sensibles a mayúsculas en MySQL/MariaDB, y mezclar "V" y "v" en la
-- misma consulta la hace fallar con "Unknown column".
SELECT
	v.estado_riesgo,
    COUNT(v.id_cliente) AS volumen_deudores,
    SUM(v.deuda_actual) AS deuda_total
FROM vw_clientes_credito_limpios AS v
-- El cliente anónimo se excluye: no es un deudor, es un contenedor técnico.
WHERE v.id_cliente <> 9999
GROUP BY v.estado_riesgo
ORDER BY deuda_total DESC;

-- ----------------------------------------------------------------------------------------------
-- KPI 4: Tasa de Utilización de Crédito
-- Pregunta de Negocio: ¿Qué porcentaje de su límite de crédito están utilizando los clientes según su riesgo?
-- BASE DECLARADA: sólo los 1.881 clientes con límite de crédito informado
-- (se excluyen los 119 sin límite y el cliente anónimo). Incluirlos con
-- límite 0 sumaba su deuda al numerador sin sumar nada al denominador y
-- sobrestimaba la utilización en ~3 puntos porcentuales.
-- ----------------------------------------------------------------------------------------------
SELECT
    v.estado_riesgo,
    COUNT(*) AS clientes_con_limite,
    SUM(v.limite_credito) AS suma_limite_credito,
    SUM(v.deuda_actual) AS deuda_total,
    CONCAT(ROUND((SUM(v.deuda_actual) / NULLIF(SUM(v.limite_credito), 0)) * 100, 1), '%') AS utilizacion
FROM vw_clientes_credito_limpios AS v
WHERE v.limite_credito IS NOT NULL
  AND v.id_cliente <> 9999
GROUP BY v.estado_riesgo
ORDER BY (SUM(v.deuda_actual) / NULLIF(SUM(v.limite_credito), 0)) DESC;

-- ==============================================================================================
-- BLOQUE 2: GESTIÓN DE PRODUCTOS E INVENTARIO 
-- Objetivo: Identificar quiebres de stock y optimizar la distribución del almacén.
-- ==============================================================================================
-- ----------------------------------------------------------------------------------------------
-- KPI 5: Alerta de Quiebre de Stock (Stock Crítico)
-- Pregunta de Negocio: ¿Qué productos están a punto de agotarse y cuánto capital representan?
-- POR QUÉ EL UMBRAL ES 15: es un parámetro de negocio, no estadístico. Se fija
-- como punto de reposición porque marca el 5,7% de las 1.600 combinaciones
-- local-producto (91 casos): un volumen que un equipo de logística alcanza a
-- gestionar en una jornada. Si el negocio cambia el criterio, se cambia aquí.
-- ----------------------------------------------------------------------------------------------
SELECT
	l.nombre_local,
    i.stock_disponible,
    p.nombre_producto,
    p.costo_compra,
    (i.stock_disponible * p.costo_compra) AS capital_inmovilizado
FROM inventario AS i 
JOIN locales AS l ON l.id_local = i.id_local
JOIN productos AS p ON i.id_producto = p.id_producto
WHERE i.stock_disponible < 15
ORDER BY i.stock_disponible ASC;

-- ----------------------------------------------------------------------------------------------
-- KPI 6: Rentabilidad por Producto (markup y margen)
-- Pregunta de Negocio: ¿Cuáles son nuestros productos estrella que dejan el mayor margen de utilidad?
-- POR QUÉ DOS INDICADORES Y NO UNO: la versión anterior llamaba "margen" a
-- (precio - costo) / COSTO, que es el markup (cuánto se recarga sobre el costo).
-- El margen comercial se calcula sobre el PRECIO DE VENTA. Las dos métricas son
-- válidas y responden preguntas distintas — compras usa markup, finanzas usa
-- margen —, pero confundir sus nombres inutiliza cualquier comparación.
-- ----------------------------------------------------------------------------------------------
SELECT
	p.nombre_producto,
    p.categoria,
    p.costo_compra,
    p.precio_venta,
    (p.precio_venta - p.costo_compra) AS ganancia_unitaria,
    ROUND(((p.precio_venta - p.costo_compra) / NULLIF(p.costo_compra, 0) * 100), 1) AS markup_sobre_costo_pct,
    ROUND(((p.precio_venta - p.costo_compra) / NULLIF(p.precio_venta, 0) * 100), 1) AS margen_sobre_precio_pct
FROM productos AS p
ORDER BY ganancia_unitaria DESC;

-- ==============================================================================================
-- BLOQUE 3: COMPORTAMIENTO Y SEGMENTACIÓN DE CLIENTES
-- Objetivo: Identificar a los consumidores de alto valor para estrategias de fidelización.
-- ==============================================================================================
-- ----------------------------------------------------------------------------------------------
-- KPI 7: Ranking de Clientes VIP (Top Compradores)
-- Pregunta de Negocio: ¿Quiénes son los 10 clientes que más ingresos generan y cuál es su frecuencia?
-- BASE DECLARADA: 1.749 clientes con al menos una compra; se excluye el id 9999.
-- POR QUÉ SE EXCLUYE: sin este filtro el ranking lo encabezaba el cliente
-- anónimo con $819.575.324, es decir 45 veces el gasto del primer cliente real.
-- El dato no se pierde: se reporta como hallazgo de calidad en el KPI 0.1.
-- ----------------------------------------------------------------------------------------------
SELECT
	c.id_cliente,
    c.nombre_completo,
    COUNT(t.id_transaccion) AS frecuencia_compra,
    SUM(t.monto_total) AS volumen_gastado
FROM vw_clientes_credito_limpios AS c
JOIN vw_transacciones_limpias AS t ON c.id_cliente = t.id_cliente
WHERE c.id_cliente <> 9999
GROUP BY c.id_cliente, c.nombre_completo
ORDER BY volumen_gastado DESC
LIMIT 10;

-- ----------------------------------------------------------------------------------------------
-- KPI 8: Segmentación de Clientes por Valor (Tiers)
-- Pregunta de Negocio: ¿Cómo se distribuye nuestra cartera de clientes según su nivel de gasto histórico?
-- BASE DECLARADA: 1.749 clientes con al menos una compra, sin el id 9999.
-- POR QUÉ CUANTILES Y NO UMBRALES FIJOS: la versión anterior cortaba en
-- $900.000 y $500.000 sobre gasto ACUMULADO, cuando el ticket promedio ya es
-- de $1,48 millones. Resultado: el 89,7% de la cartera quedaba clasificada
-- como "VIP", un tier que no permite decidir nada. NTILE(3) reparte la cartera
-- en tres tercios iguales por gasto, así el corte lo fija la distribución real
-- y no un número elegido a ojo. Si el negocio prefiere umbrales de pesos, se
-- fijan mirando estos cortes, no al revés.
-- ----------------------------------------------------------------------------------------------
WITH gasto_por_cliente AS (
    SELECT
        c.id_cliente,
        SUM(t.monto_total) AS total_gastado
    FROM vw_clientes_credito_limpios AS c
    JOIN vw_transacciones_limpias AS t ON c.id_cliente = t.id_cliente
    WHERE c.id_cliente <> 9999
    GROUP BY c.id_cliente
),
cartera_segmentada AS (
    SELECT
        id_cliente,
        total_gastado,
        NTILE(3) OVER (ORDER BY total_gastado DESC) AS tercil
    FROM gasto_por_cliente
)
SELECT
    CASE tercil WHEN 1 THEN '1 - ALTO' WHEN 2 THEN '2 - MEDIO' ELSE '3 - BAJO' END AS segmento,
    COUNT(id_cliente) AS cantidad_clientes,
    MIN(total_gastado) AS gasto_minimo_del_tramo,
    MAX(total_gastado) AS gasto_maximo_del_tramo,
    SUM(total_gastado) AS ingresos_por_segmento,
    ROUND(100.0 * SUM(total_gastado) / SUM(SUM(total_gastado)) OVER (), 1) AS pct_ingresos
FROM cartera_segmentada
GROUP BY tercil
ORDER BY tercil;

-- ==============================================================================================
-- BLOQUE 4: SQL AVANZADO (WINDOW FUNCTIONS Y CTEs)
-- Objetivo: Demostrar dominio en funciones de ventana y expresiones de tabla comunes para análisis complejos.
-- ==============================================================================================
-- ----------------------------------------------------------------------------------------------
-- KPI 9: Top 3 Clientes por Sucursal (Ranking Regional)
-- Pregunta de Negocio: ¿Quiénes son los 3 clientes más valiosos en cada uno de nuestros locales?
-- BASE DECLARADA: sin el id 9999, que de lo contrario encabeza los 16 locales.
-- POR QUÉ SE AGRUPA POR id_cliente Y NO POR nombre_completo: dos clientes
-- distintos con el mismo nombre se fusionarían en una sola fila. En este
-- dataset no ocurre (los 2.000 nombres son únicos), pero agrupar por una
-- columna que no es clave es un error que sí aparece con datos reales.
-- ----------------------------------------------------------------------------------------------
WITH GastoPorClienteLocal AS(
    SELECT
    	l.nombre_local,
    	c.id_cliente,
    	c.nombre_completo,
    	SUM(t.monto_total) AS gastado_total_cliente,
    	DENSE_RANK() OVER (PARTITION BY l.nombre_local ORDER BY SUM(t.monto_total) DESC) AS ranking_local
    FROM vw_clientes_credito_limpios AS c
    JOIN vw_transacciones_limpias AS t ON c.id_cliente = t.id_cliente
    JOIN locales AS l ON t.id_local = l.id_local
    WHERE c.id_cliente <> 9999
    GROUP BY l.nombre_local, c.id_cliente, c.nombre_completo
)
SELECT *
FROM GastoPorClienteLocal
WHERE ranking_local <= 3
ORDER BY nombre_local ASC, ranking_local ASC;

-- ----------------------------------------------------------------------------------------------
-- KPI 10: Crecimiento Mes a Mes (Inteligencia de Tiempo)
-- Pregunta de Negocio: ¿Cuál es la tendencia de nuestros ingresos mensuales y nuestro % de crecimiento?
-- BASE DECLARADA: 4.450 transacciones (89,0%) por $6.591.729.048 (88,9% de la
-- facturación). Se excluyen las 550 transacciones cuya fecha venía en texto.
-- POR QUÉ SE EXCLUYEN AUNQUE AHORA SÍ SE PARSEAN: en el dataset versionado el
-- generador emitía ese formato con un literal fijo ('18 mayo 25'), de modo que
-- las 550 caen todas el mismo día. Incorporarlas triplicaría mayo e inventaría
-- un peak comercial que no existe. El generador ya está corregido (escribe la
-- fecha real en texto), así que en datasets nuevos este filtro sobra: se deja
-- explícito y declarado en vez de silencioso.
-- ----------------------------------------------------------------------------------------------
WITH VentasMensuales AS (
    SELECT
        DATE_FORMAT(fecha_venta, '%Y-%m') AS mes_venta,
        SUM(monto_total) AS ingresos_del_mes
    FROM vw_transacciones_limpias
    WHERE fecha_venta IS NOT NULL
      AND formato_fecha_origen <> 'TEXTO'
    GROUP BY DATE_FORMAT(fecha_venta, '%Y-%m')
)
SELECT 
    mes_venta,
    ingresos_del_mes,
    LAG(ingresos_del_mes, 1) OVER (ORDER BY mes_venta) AS ingresos_mes_anterior,
    ROUND(
        ((ingresos_del_mes - LAG(ingresos_del_mes, 1) OVER (ORDER BY mes_venta))
        / NULLIF(LAG(ingresos_del_mes, 1) OVER (ORDER BY mes_venta), 0)) * 100,1) AS porcentaje_crecimiento
FROM VentasMensuales
ORDER BY mes_venta ASC;

-- ==============================================================================================
-- BLOQUE 5: MIX DE PRODUCTO Y CONCENTRACIÓN DE CARTERA
-- Objetivo: cerrar dos vacíos del análisis anterior — la tabla de detalle no se
-- usaba en ningún KPI, y la afirmación "tecnología es lo que más vende" no
-- estaba respaldada por ninguna consulta.
-- ==============================================================================================
-- ----------------------------------------------------------------------------------------------
-- KPI 11: Venta por Categoría de Producto
-- Pregunta de Negocio: ¿Qué categorías sostienen la facturación y con qué volumen de unidades?
-- Base: las 12.520 líneas de detalle_transacciones (100% del detalle).
-- ----------------------------------------------------------------------------------------------
SELECT
    p.categoria,
    SUM(d.cantidad) AS unidades_vendidas,
    SUM(d.subtotal) AS venta_total,
    ROUND(100.0 * SUM(d.subtotal) / SUM(SUM(d.subtotal)) OVER (), 1) AS pct_venta
FROM detalle_transacciones AS d
JOIN productos AS p ON d.id_producto = p.id_producto
GROUP BY p.categoria
ORDER BY venta_total DESC;

-- ----------------------------------------------------------------------------------------------
-- KPI 12: Categoría líder por Local
-- Pregunta de Negocio: ¿La categoría que más vende es la misma en los 16 locales?
-- ----------------------------------------------------------------------------------------------
WITH VentaCategoriaLocal AS (
    SELECT
        l.nombre_local,
        p.categoria,
        SUM(d.subtotal) AS venta_local_categoria,
        ROW_NUMBER() OVER (PARTITION BY l.nombre_local ORDER BY SUM(d.subtotal) DESC) AS ranking
    FROM detalle_transacciones AS d
    JOIN vw_transacciones_limpias AS t ON d.id_transaccion = t.id_transaccion
    JOIN locales AS l ON t.id_local = l.id_local
    JOIN productos AS p ON d.id_producto = p.id_producto
    GROUP BY l.nombre_local, p.categoria
)
SELECT
    categoria AS categoria_lider,
    COUNT(*) AS locales_donde_lidera
FROM VentaCategoriaLocal
WHERE ranking = 1
GROUP BY categoria
ORDER BY locales_donde_lidera DESC;

-- ----------------------------------------------------------------------------------------------
-- KPI 13: Concentración de la Facturación (prueba de Pareto)
-- Pregunta de Negocio: ¿Existe un grupo pequeño de clientes que concentre la venta?
-- POR QUÉ ESTA CONSULTA EXISTE: para no dar por hecho el 80/20. La respuesta en
-- este dataset es que NO hay concentración — hacen falta 948 de 1.749 clientes
-- (54,2%) para acumular el 80% de la venta. Es consecuencia directa de que los
-- datos son sintéticos con distribución uniforme, y es la limitación más
-- importante del proyecto: sirve para ejercitar el pipeline, no para concluir
-- sobre comportamiento de clientes reales.
-- ----------------------------------------------------------------------------------------------
WITH gasto_por_cliente AS (
    SELECT
        c.id_cliente,
        SUM(t.monto_total) AS total_gastado
    FROM vw_clientes_credito_limpios AS c
    JOIN vw_transacciones_limpias AS t ON c.id_cliente = t.id_cliente
    WHERE c.id_cliente <> 9999
    GROUP BY c.id_cliente
),
acumulado AS (
    SELECT
        id_cliente,
        total_gastado,
        ROW_NUMBER() OVER (ORDER BY total_gastado DESC) AS posicion,
        SUM(total_gastado) OVER (ORDER BY total_gastado DESC ROWS UNBOUNDED PRECEDING)
            / SUM(total_gastado) OVER () AS pct_acumulado,
        COUNT(*) OVER () AS clientes_totales
    FROM gasto_por_cliente
)
SELECT
    MIN(posicion) AS clientes_para_80pct_de_la_venta,
    MIN(clientes_totales) AS clientes_totales,
    ROUND(100.0 * MIN(posicion) / MIN(clientes_totales), 1) AS pct_cartera_necesaria
FROM acumulado
WHERE pct_acumulado >= 0.80;




