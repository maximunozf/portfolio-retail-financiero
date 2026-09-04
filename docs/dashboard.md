# Dashboard Power BI — `dashboard/retail_financiero_dashboard.pbix`

> Para revisarlo sin instalar Power BI: [`dashboard/dashboard_retail_financiero.pdf`](../dashboard/dashboard_retail_financiero.pdf).
> Es un export de las tres páginas, no un informe interactivo: los segmentadores de región y fecha no funcionan ahí.

Conecta directamente a las **vistas de limpieza** de MySQL (`vw_transacciones_limpias`, `vw_clientes_credito_limpios`), no a las tablas crudas. Es decisión de diseño: la limpieza vive en SQL y el dashboard no la duplica en Power Query, así una corrección en la vista se propaga al informe con un solo refresh.

## Modelo

| Tabla | Rol | Origen |
|---|---|---|
| `vw_transacciones_limpias` | Hechos — venta | Vista MySQL |
| `vw_clientes_credito_limpios` | Hechos — cartera | Vista MySQL |
| `detalle_transacciones` | Hechos — línea de venta | Tabla MySQL |
| `productos`, `locales` | Dimensiones | Tablas MySQL |
| `Calendario` | Dimensión de tiempo | Tabla calculada con DAX |
| `_Medidas` | Tabla contenedora de medidas | Tabla manual; su única columna (`Columna1`) está oculta porque Power BI no permite borrar la última columna de una tabla |

**Por qué una tabla `Calendario` propia:** las funciones de inteligencia de tiempo de DAX necesitan una dimensión de fechas continua y marcada como tabla de fechas. Usar directamente `fecha_venta` deja huecos en los días sin venta y rompe cualquier comparación período a período.

## Páginas

**1 · Visión General** — Ganancia Neta, Margen de Utilidad %, Ticket Promedio y Deuda Total; venta por sucursal (barras) y deuda por estado de riesgo (anillo). Segmentadores de región y de fecha.

**2 · Detalle de Ventas** — unidades vendidas, cantidad de transacciones, ticket promedio, % de ventas a crédito; top categorías y evolución mensual de ventas.

**3 · Cartera y Riesgo** — deuda total, deuda promedio por cliente, % de cartera en mora, N° de clientes en riesgo; dispersión deuda vs. límite de crédito y la tabla *Top 15 Clientes en Mora*, ordenada por deuda actual descendente. Los clientes sin límite informado aparecen con la etiqueta "Sin límite informado" en vez de un $0 que sugeriría sobregiro.

## Decisiones y limitaciones del informe

**Los indicadores de cartera no responden al segmentador de fechas.** `deuda_actual` es un saldo a una fecha de corte, no un flujo acumulable: filtrarlo por rango de fechas daría un número sin significado. Sí responden al segmentador de región. Está dicho aquí porque es la primera pregunta que genera el dashboard al mirarlo.

**La evolución mensual excluye las 550 transacciones cuya fecha venía en texto.** En el dataset versionado todas caen el mismo día por un defecto del generador (ya corregido); incluirlas inventaría un peak en mayo. El filtro se aplica sobre la columna `formato_fecha_origen` de la vista. Base del gráfico: 4.450 transacciones (89,0%), $6.591.728.756.

**El cliente anónimo (id 9999) no distorsiona los visuales de cartera** porque entra con deuda 0 y estado `SIN RIESGO`. Sí está incluido —correctamente— en los visuales de venta, donde representa el 11,05% de la facturación.

**Los 119 clientes sin límite de crédito informado quedan fuera de la dispersión deuda vs. límite**, porque su límite es `NULL` y no 0. Antes formaban una columna artificial pegada al eje.
