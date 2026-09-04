"""
==============================================================================
PROYECTO: RETAIL FINANCIERO & LOGÍSTICA
ARCHIVO: 04_verificacion_kpis.py
OBJETIVO: Recalcular, desde los CSV crudos, todas las cifras publicadas en el
          README y en el dashboard.

POR QUÉ EXISTE ESTE SCRIPT:
Una cifra sin forma de reproducirla es indistinguible de una cifra mal
calculada para quien la lee desde afuera. Este script replica en Python/SQL
(DuckDB) las mismas vistas y consultas de 02_data_wrangling.sql y
03_business_analytics.sql, partiendo de los CSV y no de MySQL. Si el resultado
coincide con lo publicado, cualquiera puede verificarlo sin instalar nada más
que Python; si algún día deja de coincidir, el README está desactualizado.

USO:
    python scripts/04_verificacion_kpis.py            # imprime el informe
    python scripts/04_verificacion_kpis.py --csv out  # además exporta los KPIs

Requiere: duckdb, pandas (ver requirements.txt).
==============================================================================
"""

import argparse
import os

import duckdb
import pandas as pd

# Por defecto pandas imprime los montos grandes en notación científica
# (8.195753e+08). Ese formato fue la causa raíz de que un monto se transcribiera
# mal al README: la cifra impresa no era legible dígito a dígito. Se fuerza
# formato fijo con separador de miles para que lo que se imprime sea exactamente
# lo que se puede copiar a la documentación.
pd.set_option('display.float_format', lambda valor: f'{valor:,.2f}')
pd.set_option('display.width', 200)
pd.set_option('display.max_columns', None)

DIR_BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR_DATOS = os.path.join(DIR_BASE, 'data')

# id técnico que 01_setup_database.sql inserta en MySQL para absorber las ventas
# sin cliente. No está en el CSV, así que aquí se agrega para que la
# verificación replique exactamente el estado de la base.
ID_CLIENTE_ANONIMO = 9999


def construir_base():
    """Carga los CSV y recrea las dos vistas de la capa plata."""
    con = duckdb.connect()
    for tabla in ['locales', 'clientes_credito', 'productos', 'inventario',
                  'transacciones', 'detalle_transacciones']:
        ruta = os.path.join(DIR_DATOS, f'{tabla}.csv').replace('\\', '/')
        # all_varchar en las dos tablas sucias: se leen como texto para que la
        # limpieza la haga el SQL, igual que en MySQL, y no el lector de CSV.
        crudo = 'true' if tabla in ('clientes_credito', 'transacciones') else 'false'
        con.execute(f"""
            CREATE TABLE {tabla} AS
            SELECT * FROM read_csv_auto('{ruta}', header=true, all_varchar={crudo})
        """)

    con.execute(f"""
        INSERT INTO clientes_credito
        VALUES ('{ID_CLIENTE_ANONIMO}', 'CLIENTE ANONIMO', '1900-01-01', '0.00', '0.00', 'SIN RIESGO')
    """)

    # vw_clientes_credito_limpios: límite ausente queda en NULL, no en 0.
    con.execute("""
        CREATE VIEW vw_clientes_credito_limpios AS
        SELECT CAST(id_cliente AS INT) AS id_cliente,
               TRIM(nombre_completo) AS nombre_completo,
               CAST(fecha_nacimiento AS DATE) AS fecha_nacimiento,
               CAST(NULLIF(TRIM(limite_credito), '') AS DECIMAL(15,2)) AS limite_credito,
               CAST(deuda_actual AS DECIMAL(15,2)) AS deuda_actual,
               UPPER(TRIM(estado_riesgo)) AS estado_riesgo
        FROM clientes_credito
    """)

    # vw_transacciones_limpias: 4 formatos de fecha + trazabilidad del origen.
    con.execute("""
        CREATE VIEW vw_transacciones_limpias AS
        SELECT CAST(id_transaccion AS INT) AS id_transaccion,
               CAST(id_local AS INT) AS id_local,
               CAST(id_cliente AS INT) AS id_cliente,
               CASE
                 WHEN regexp_matches(fecha_venta, '^[0-9]{2}/[0-9]{2}/[0-9]{4}$')
                      THEN strptime(fecha_venta, '%d/%m/%Y')::DATE
                 WHEN regexp_matches(fecha_venta, '^[0-9]{2}-[0-9]{2}-[0-9]{4}$')
                      THEN strptime(fecha_venta, '%d-%m-%Y')::DATE
                 WHEN regexp_matches(fecha_venta, '^[0-9]{4}-[0-9]{2}-[0-9]{2}$')
                      THEN strptime(fecha_venta, '%Y-%m-%d')::DATE
                 WHEN regexp_matches(fecha_venta, '^[0-9]{1,2} [a-zA-Z]+ [0-9]{2}$')
                      THEN strptime(
                             split_part(fecha_venta, ' ', 1) || '-' ||
                             CASE lower(split_part(fecha_venta, ' ', 2))
                               WHEN 'enero' THEN '01' WHEN 'febrero' THEN '02'
                               WHEN 'marzo' THEN '03' WHEN 'abril' THEN '04'
                               WHEN 'mayo' THEN '05' WHEN 'junio' THEN '06'
                               WHEN 'julio' THEN '07' WHEN 'agosto' THEN '08'
                               WHEN 'septiembre' THEN '09' WHEN 'octubre' THEN '10'
                               WHEN 'noviembre' THEN '11' WHEN 'diciembre' THEN '12'
                             END || '-' || split_part(fecha_venta, ' ', 3),
                             '%d-%m-%y')::DATE
                 ELSE NULL
               END AS fecha_venta,
               CASE
                 WHEN regexp_matches(fecha_venta, '^[0-9]{4}-[0-9]{2}-[0-9]{2}$') THEN 'ISO'
                 WHEN regexp_matches(fecha_venta, '^[0-9]{2}/[0-9]{2}/[0-9]{4}$') THEN 'DD/MM/AAAA'
                 WHEN regexp_matches(fecha_venta, '^[0-9]{2}-[0-9]{2}-[0-9]{4}$') THEN 'DD-MM-AAAA'
                 WHEN regexp_matches(fecha_venta, '^[0-9]{1,2} [a-zA-Z]+ [0-9]{2}$') THEN 'TEXTO'
                 ELSE 'NO_RECONOCIDO'
               END AS formato_fecha_origen,
               CAST(monto_total AS DECIMAL(15,2)) AS monto_total,
               CASE
                 WHEN UPPER(TRIM(tipo_pago)) = 'EFECTIVO' THEN 'EFECTIVO'
                 WHEN UPPER(TRIM(tipo_pago)) = 'DEBITO' THEN 'DEBITO'
                 WHEN UPPER(TRIM(tipo_pago)) = 'CREDITO' THEN 'CREDITO'
                 WHEN UPPER(TRIM(tipo_pago)) = 'CREDITO TIENDA' THEN 'CREDITO'
                 ELSE 'OTROS / POR CLASIFICAR'
               END AS tipo_pago,
               CAST(cantidad_cuotas AS INT) AS cantidad_cuotas
        FROM transacciones
    """)
    return con


# Cada entrada replica un KPI de 03_business_analytics.sql.
CONSULTAS = [
    ("0.1 Calidad — peso del cliente anónimo (id 9999)", """
        SELECT COUNT(*) AS transacciones,
               SUM(CASE WHEN id_cliente = 9999 THEN 1 ELSE 0 END) AS sin_cliente,
               ROUND(100.0 * SUM(CASE WHEN id_cliente = 9999 THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_trans,
               SUM(monto_total) AS facturacion,
               SUM(CASE WHEN id_cliente = 9999 THEN monto_total ELSE 0 END) AS facturacion_sin_cliente,
               ROUND(100.0 * SUM(CASE WHEN id_cliente = 9999 THEN monto_total ELSE 0 END) / SUM(monto_total), 2) AS pct_fact
        FROM vw_transacciones_limpias"""),

    ("0.2 Calidad — formatos de fecha en el origen", """
        SELECT formato_fecha_origen, COUNT(*) AS transacciones,
               ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct,
               SUM(monto_total) AS facturacion,
               SUM(CASE WHEN fecha_venta IS NULL THEN 1 ELSE 0 END) AS no_parseadas
        FROM vw_transacciones_limpias GROUP BY 1 ORDER BY transacciones DESC"""),

    ("0.3 Calidad — clientes sin límite de crédito", """
        SELECT COUNT(*) AS clientes,
               SUM(CASE WHEN limite_credito IS NULL THEN 1 ELSE 0 END) AS sin_limite,
               ROUND(100.0 * SUM(CASE WHEN limite_credito IS NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct
        FROM vw_clientes_credito_limpios WHERE id_cliente <> 9999"""),

    ("1 Facturación por sucursal (top 5)", """
        SELECT l.nombre_local, COUNT(*) AS transacciones, SUM(v.monto_total) AS facturacion
        FROM locales l JOIN vw_transacciones_limpias v ON l.id_local = v.id_local
        GROUP BY 1 ORDER BY facturacion DESC LIMIT 5"""),

    ("2 Distribución por método de pago", """
        SELECT tipo_pago, COUNT(*) AS transacciones, SUM(monto_total) AS facturacion,
               ROUND(100.0 * SUM(monto_total) / SUM(SUM(monto_total)) OVER (), 1) AS pct
        FROM vw_transacciones_limpias GROUP BY 1 ORDER BY facturacion DESC"""),

    ("3 Exposición de deuda por estado de riesgo", """
        SELECT estado_riesgo, COUNT(*) AS deudores, SUM(deuda_actual) AS deuda,
               ROUND(100.0 * SUM(deuda_actual) / SUM(SUM(deuda_actual)) OVER (), 1) AS pct_deuda
        FROM vw_clientes_credito_limpios WHERE id_cliente <> 9999
        GROUP BY 1 ORDER BY deuda DESC"""),

    ("4 Utilización de crédito (sólo clientes con límite informado)", """
        SELECT estado_riesgo, COUNT(*) AS clientes_con_limite,
               SUM(limite_credito) AS limite, SUM(deuda_actual) AS deuda,
               ROUND(100.0 * SUM(deuda_actual) / NULLIF(SUM(limite_credito), 0), 1) AS utilizacion_pct
        FROM vw_clientes_credito_limpios
        WHERE limite_credito IS NOT NULL AND id_cliente <> 9999
        GROUP BY 1 ORDER BY utilizacion_pct DESC"""),

    ("5 Stock crítico (< 15 unidades)", """
        SELECT COUNT(*) AS combinaciones_local_producto,
               ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM inventario), 1) AS pct_del_inventario,
               SUM(i.stock_disponible * p.costo_compra) AS capital_inmovilizado
        FROM inventario i JOIN productos p ON i.id_producto = p.id_producto
        WHERE i.stock_disponible < 15"""),

    ("7 Top 5 clientes reales (sin id 9999)", """
        SELECT c.id_cliente, COUNT(*) AS frecuencia, SUM(t.monto_total) AS gasto
        FROM vw_clientes_credito_limpios c
        JOIN vw_transacciones_limpias t ON c.id_cliente = t.id_cliente
        WHERE c.id_cliente <> 9999 GROUP BY 1 ORDER BY gasto DESC LIMIT 5"""),

    ("7b Comparación: cuántas veces el anónimo supera al primer cliente real", """
        WITH g AS (SELECT id_cliente, SUM(monto_total) gasto FROM vw_transacciones_limpias GROUP BY 1)
        SELECT (SELECT gasto FROM g WHERE id_cliente = 9999) AS gasto_anonimo,
               (SELECT MAX(gasto) FROM g WHERE id_cliente <> 9999) AS gasto_primer_real,
               ROUND((SELECT gasto FROM g WHERE id_cliente = 9999)
                     / (SELECT MAX(gasto) FROM g WHERE id_cliente <> 9999), 1) AS veces"""),

    ("8a Segmentación ANTERIOR (umbrales fijos, con el anónimo)", """
        SELECT tipo_cliente, COUNT(*) AS clientes,
               ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_cartera
        FROM (SELECT c.id_cliente, SUM(t.monto_total) g,
                     CASE WHEN SUM(t.monto_total) >= 900000 THEN 'VIP'
                          WHEN SUM(t.monto_total) >= 500000 THEN 'Regular'
                          ELSE 'Esporadico' END AS tipo_cliente
              FROM vw_clientes_credito_limpios c
              JOIN vw_transacciones_limpias t ON c.id_cliente = t.id_cliente
              GROUP BY 1) GROUP BY 1 ORDER BY clientes DESC"""),

    ("8b Segmentación CORREGIDA (terciles, sin el anónimo)", """
        WITH g AS (SELECT c.id_cliente, SUM(t.monto_total) total_gastado
                   FROM vw_clientes_credito_limpios c
                   JOIN vw_transacciones_limpias t ON c.id_cliente = t.id_cliente
                   WHERE c.id_cliente <> 9999 GROUP BY 1),
             s AS (SELECT *, NTILE(3) OVER (ORDER BY total_gastado DESC) tercil FROM g)
        SELECT CASE tercil WHEN 1 THEN '1 - ALTO' WHEN 2 THEN '2 - MEDIO' ELSE '3 - BAJO' END AS segmento,
               COUNT(*) AS clientes, MIN(total_gastado) AS gasto_min, MAX(total_gastado) AS gasto_max,
               SUM(total_gastado) AS ingresos,
               ROUND(100.0 * SUM(total_gastado) / SUM(SUM(total_gastado)) OVER (), 1) AS pct_ingresos
        FROM s GROUP BY tercil ORDER BY tercil"""),

    ("10 Ingresos mensuales (excluye las fechas en texto)", """
        SELECT strftime(fecha_venta, '%Y-%m') AS mes, COUNT(*) AS transacciones,
               SUM(monto_total) AS ingresos
        FROM vw_transacciones_limpias
        WHERE fecha_venta IS NOT NULL AND formato_fecha_origen <> 'TEXTO'
        GROUP BY 1 ORDER BY 1"""),

    ("10b Base declarada del KPI mensual", """
        SELECT COUNT(*) AS transacciones_incluidas, SUM(monto_total) AS facturacion_incluida,
               ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM vw_transacciones_limpias), 1) AS pct_transacciones,
               ROUND(100.0 * SUM(monto_total) / (SELECT SUM(monto_total) FROM vw_transacciones_limpias), 1) AS pct_facturacion
        FROM vw_transacciones_limpias
        WHERE fecha_venta IS NOT NULL AND formato_fecha_origen <> 'TEXTO'"""),

    ("11 Venta por categoría de producto", """
        SELECT p.categoria, SUM(d.cantidad) AS unidades, SUM(d.subtotal) AS venta,
               ROUND(100.0 * SUM(d.subtotal) / SUM(SUM(d.subtotal)) OVER (), 1) AS pct
        FROM detalle_transacciones d JOIN productos p ON d.id_producto = p.id_producto
        GROUP BY 1 ORDER BY venta DESC"""),

    ("12 Categoría líder por local", """
        WITH x AS (SELECT l.nombre_local, p.categoria, SUM(d.subtotal) v,
                          ROW_NUMBER() OVER (PARTITION BY l.nombre_local ORDER BY SUM(d.subtotal) DESC) rn
                   FROM detalle_transacciones d
                   JOIN vw_transacciones_limpias t ON d.id_transaccion = t.id_transaccion
                   JOIN locales l ON t.id_local = l.id_local
                   JOIN productos p ON d.id_producto = p.id_producto
                   GROUP BY 1, 2)
        SELECT categoria AS categoria_lider, COUNT(*) AS locales_donde_lidera
        FROM x WHERE rn = 1 GROUP BY 1 ORDER BY 2 DESC"""),

    ("13 Concentración de la venta (prueba de Pareto)", """
        WITH g AS (SELECT c.id_cliente, SUM(t.monto_total) gasto
                   FROM vw_clientes_credito_limpios c
                   JOIN vw_transacciones_limpias t ON c.id_cliente = t.id_cliente
                   WHERE c.id_cliente <> 9999 GROUP BY 1),
             a AS (SELECT id_cliente,
                          ROW_NUMBER() OVER (ORDER BY gasto DESC) posicion,
                          SUM(gasto) OVER (ORDER BY gasto DESC ROWS UNBOUNDED PRECEDING)
                            / SUM(gasto) OVER () pct_acum,
                          COUNT(*) OVER () clientes_totales
                   FROM g)
        SELECT MIN(posicion) AS clientes_para_80pct, MIN(clientes_totales) AS clientes_totales,
               ROUND(100.0 * MIN(posicion) / MIN(clientes_totales), 1) AS pct_cartera
        FROM a WHERE pct_acum >= 0.80"""),

    ("Control de integridad — detalle vs. monto_total de la transacción", """
        SELECT COUNT(*) AS transacciones_descuadradas FROM (
            SELECT t.id_transaccion FROM vw_transacciones_limpias t
            JOIN detalle_transacciones d ON t.id_transaccion = d.id_transaccion
            GROUP BY 1, t.monto_total HAVING ABS(t.monto_total - SUM(d.subtotal)) > 0.01)"""),
]


def main():
    parser = argparse.ArgumentParser(description='Verifica las cifras publicadas del proyecto.')
    parser.add_argument('--csv', metavar='CARPETA',
                        help='Exporta cada KPI a un CSV dentro de la carpeta indicada.')
    args = parser.parse_args()

    con = construir_base()
    if args.csv:
        os.makedirs(args.csv, exist_ok=True)

    for titulo, sql in CONSULTAS:
        df = con.execute(sql).df()
        print('=' * 78)
        print(titulo)
        print('-' * 78)
        print(df.to_string(index=False))
        print()
        if args.csv:
            nombre = titulo.split(' ')[0].replace('.', '_')
            df.to_csv(os.path.join(args.csv, f'kpi_{nombre}.csv'), index=False)

    print('=' * 78)
    print('Verificación completa. Estas cifras son las que deben aparecer en el')
    print('README y en el dashboard. Si alguna difiere, la desactualizada es la')
    print('publicada, no esta.')


if __name__ == '__main__':
    main()
