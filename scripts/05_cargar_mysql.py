"""
==============================================================================
PROYECTO: RETAIL FINANCIERO & LOGÍSTICA
ARCHIVO: 05_cargar_mysql.py
OBJETIVO: Reconstruir la base completa en MySQL desde cero, en un comando.

POR QUÉ EXISTE:
Cargar 6 CSV a mano por el asistente de importación deja el proyecto
dependiendo de que alguien haga bien 6 veces la misma secuencia de clics. Este
script ejecuta el DDL, inserta los datos en el orden que exigen las claves
foráneas y crea las vistas de limpieza, siempre igual.

POR QUÉ INSERT POR LOTES Y NO 'LOAD DATA LOCAL INFILE':
LOAD DATA es más rápido, pero exige que el servidor tenga local_infile=ON y que
los archivos estén donde permita secure_file_priv. Son dos configuraciones que
fallan distinto en cada instalación. Con 12.520 filas como máximo, un
executemany por lotes tarda segundos y funciona en cualquier servidor sin
tocarle la configuración a nadie.

USO:
    python scripts/05_cargar_mysql.py --password TU_CLAVE
    python scripts/05_cargar_mysql.py --host localhost --port 3306 --user root --password TU_CLAVE

Requiere: mysql-connector-python (ver requirements.txt).
==============================================================================
"""

import argparse
import csv
import os
import re
import sys

try:
    import mysql.connector
except ImportError:
    sys.exit("Falta la librería. Corre primero:  pip install mysql-connector-python")

DIR_BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIR_DATOS = os.path.join(DIR_BASE, 'data')
DIR_SQL = os.path.join(DIR_BASE, 'sql')

BASE_DATOS = 'retail_financiero'

# Orden obligatorio: primero las dimensiones, después los hechos que las
# referencian. Invertirlo hace fallar las claves foráneas.
TABLAS = [
    ('locales', 3),
    ('clientes_credito', 6),
    ('productos', 5),
    ('inventario', 4),
    ('transacciones', 7),
    ('detalle_transacciones', 5),
]


def sentencias(ruta_sql):
    """Divide un archivo .sql en sentencias ejecutables.

    Quita los comentarios de línea (--) antes de separar por ';' para que un
    ';' que aparezca dentro de un comentario no parta una sentencia en dos.
    """
    with open(ruta_sql, encoding='utf-8') as f:
        texto = f.read()
    texto = re.sub(r'--[^\n]*', '', texto)
    return [s.strip() for s in texto.split(';') if s.strip()]


def cargar_csv(cursor, tabla, n_columnas):
    ruta = os.path.join(DIR_DATOS, f'{tabla}.csv')
    with open(ruta, encoding='utf-8', newline='') as f:
        lector = csv.reader(f)
        next(lector)  # la primera fila son los nombres de columna
        filas = [fila for fila in lector if fila]

    marcadores = ', '.join(['%s'] * n_columnas)
    sql = f'INSERT INTO {tabla} VALUES ({marcadores})'

    # Se inserta en lotes de 1.000 para no armar una sola sentencia gigante.
    for inicio in range(0, len(filas), 1000):
        cursor.executemany(sql, filas[inicio:inicio + 1000])
    return len(filas)


def main():
    p = argparse.ArgumentParser(description='Reconstruye la base retail_financiero en MySQL.')
    p.add_argument('--host', default='localhost')
    p.add_argument('--port', type=int, default=3306)
    p.add_argument('--user', default='root')
    p.add_argument('--password', default='')
    args = p.parse_args()

    con = mysql.connector.connect(host=args.host, port=args.port,
                                  user=args.user, password=args.password)
    cur = con.cursor()

    print(f'Conectado a {args.host}:{args.port} como {args.user}.')

    # 1. DDL: base, tablas, claves foráneas y el cliente anónimo.
    print('1/3  Creando base y tablas (01_setup_database.sql)...')
    cur.execute(f'DROP DATABASE IF EXISTS {BASE_DATOS}')
    for s in sentencias(os.path.join(DIR_SQL, '01_setup_database.sql')):
        cur.execute(s)
    con.database = BASE_DATOS

    # 2. Datos, en orden de dependencia.
    print('2/3  Cargando los CSV...')
    for tabla, n_col in TABLAS:
        # clientes_credito ya trae el id 9999 insertado por el DDL: se cargan
        # los 2.000 clientes del CSV encima, sin tocarlo.
        n = cargar_csv(cur, tabla, n_col)
        print(f'       {tabla:<24} {n:>6} filas')
    con.commit()

    # 3. Vistas de limpieza. El archivo trae también las consultas de
    #    perfilamiento; se ejecutan igual y sus resultados se descartan aquí.
    print('3/3  Creando vistas de limpieza (02_data_wrangling.sql)...')
    for s in sentencias(os.path.join(DIR_SQL, '02_data_wrangling.sql')):
        cur.execute(s)
        try:
            cur.fetchall()
        except mysql.connector.errors.InterfaceError:
            pass  # las sentencias DDL no devuelven filas
    con.commit()

    # Control rápido de que quedó cargado lo que corresponde.
    cur.execute('SELECT COUNT(*) FROM vw_transacciones_limpias')
    n_trans = cur.fetchone()[0]
    cur.execute('SELECT SUM(monto_total) FROM vw_transacciones_limpias')
    facturacion = cur.fetchone()[0]

    cur.close()
    con.close()

    print()
    print(f'Listo. {n_trans} transacciones, facturación {facturacion}.')
    print('Debe decir 5000 y 7417609719.08. Si no coincide, los CSV no son los del repo.')


if __name__ == '__main__':
    main()
