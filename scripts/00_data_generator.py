import argparse
import csv
import os
import random
from datetime import datetime, timedelta

# ==============================================================================
# PROYECTO: RETAIL FINANCIERO & LOGÍSTICA
# ARCHIVO: 00_data_generator.py
# OBJETIVO: Generar el dataset sintético del proyecto (6 tablas relacionadas).
#
# POR QUÉ DATOS SINTÉTICOS: no existe una fuente pública con el detalle
# transaccional, crediticio y de inventario que este análisis necesita. Los
# datos se generan sucios A PROPÓSITO (huérfanos, nulos, fechas en 4 formatos,
# inconsistencias de texto) para que la limpieza en SQL sea un ejercicio real
# y no una formalidad.
#
# POR QUÉ UNA SEMILLA FIJA: sin semilla, cada ejecución produce un dataset
# distinto y ninguna cifra publicada se puede reproducir. Con la semilla, el
# pipeline completo es verificable por un tercero.
# ==============================================================================

SEMILLA = 42
random.seed(SEMILLA)

# La fecha de nacimiento se calculaba con datetime.now(), lo que hacía que el
# CSV cambiara según el día en que se corriera el script. Se fija una fecha de
# referencia para que la salida dependa solo de la semilla.
FECHA_REFERENCIA = datetime(2026, 1, 1)

# id_cliente reservado para las ventas sin cliente identificable. Se genera a
# propósito (~10% de las transacciones) para simular el error de integridad
# referencial más común en sistemas de punto de venta.
ID_CLIENTE_ANONIMO = 9999

MESES_ES = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
            'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre']

parser = argparse.ArgumentParser(description='Genera el dataset sintético del proyecto.')
parser.add_argument('--out', default='data',
                    help='Carpeta de salida de los CSV (por defecto: data/).')
parser.add_argument('--force', action='store_true',
                    help='Sobrescribe los CSV existentes.')
args = parser.parse_args()

OUT = args.out
os.makedirs(OUT, exist_ok=True)

# Los CSV versionados en data/ son el dataset canónico sobre el que se
# calcularon TODAS las cifras publicadas en el README. Sobrescribirlos sin
# querer invalidaría esas cifras, por eso el script se niega salvo --force.
if not args.force and os.path.exists(os.path.join(OUT, 'transacciones.csv')):
    raise SystemExit(
        f"Ya existen CSV en '{OUT}/'. Ese es el dataset canónico del proyecto.\n"
        f"Si de verdad quieres regenerarlo, corre: python scripts/00_data_generator.py --force"
    )

def ruta(nombre):
    return os.path.join(OUT, nombre)

print("Iniciando generación del Data Warehouse corporativo...")

# 1. LOCALES
regiones = [
    (1, 'Arica', 'Arica y Parinacota'), (2, 'Iquique', 'Tarapaca'), 
    (3, 'Antofagasta', 'Antofagasta'), (4, 'Copiapo', 'Atacama'), 
    (5, 'La Serena', 'Coquimbo'), (6, 'Valparaiso', 'Valparaiso'), 
    (7, 'Santiago Centro', 'Metropolitana'), (8, 'Rancagua', 'O Higgins'), 
    (9, 'Talca', 'Maule'), (10, 'Chillan', 'Nuble'), 
    (11, 'Concepcion', 'Biobio'), (12, 'Temuco', 'Araucania'), 
    (13, 'Valdivia', 'Los Rios'), (14, 'Puerto Montt', 'Los Lagos'), 
    (15, 'Coyhaique', 'Aysen'), (16, 'Punta Arenas', 'Magallanes')
]
with open(ruta('locales.csv'), 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(['id_local', 'nombre_local', 'region'])
    writer.writerows(regiones)

# 2. CLIENTES_CREDITO
clientes = []
estados = ['AL DIA', 'MOROSO', 'CASTIGADO', ' al dia ', 'MOROSO ']
for i in range(1, 2001):
    nombre = f"Cliente_{i}"
    if random.random() < 0.1: nombre = f"  {nombre.lower()}  " 
    
    dias_edad = random.randint(18*365, 70*365)
    fecha_nac = (FECHA_REFERENCIA - timedelta(days=dias_edad)).strftime('%Y-%m-%d')
    
    limite = round(random.uniform(200000, 3000000), 2)
    uso_credito = random.uniform(0.0, 0.95)
    deuda = round(limite * uso_credito, 2)
    
    # Suciedad intencional: ~5% de los clientes queda sin límite de crédito.
    # Es el caso que obliga a decidir en SQL si un límite ausente se trata como
    # NULL o como cero — decisión que cambia la tasa de utilización de crédito.
    if random.random() < 0.05: limite = ''
    
    estado = random.choice(estados)
    clientes.append([i, nombre, fecha_nac, limite, deuda, estado])

with open(ruta('clientes_credito.csv'), 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(['id_cliente', 'nombre_completo', 'fecha_nacimiento', 'limite_credito', 'deuda_actual', 'estado_riesgo'])
    writer.writerows(clientes)

# 3. PRODUCTOS
productos = []
for i in range(1, 101):
    cat_rand = random.random()
    if cat_rand < 0.4:
        cat = 'Tecnologia'
        costo = round(random.uniform(50000, 600000), 2)
        precio = round(costo * 1.15, 2)
    elif cat_rand < 0.7:
        cat = 'Linea Blanca'
        costo = round(random.uniform(100000, 400000), 2)
        precio = round(costo * 1.30, 2)
    elif cat_rand < 0.9:
        cat = 'Muebles'
        costo = round(random.uniform(30000, 200000), 2)
        precio = round(costo * 2.50, 2)
    else:
        cat = 'Ferreteria'
        costo = round(random.uniform(10000, 150000), 2)
        precio = round(costo * 1.50, 2)
        
    productos.append([i, cat, f"Producto_{cat}_{i}", costo, precio])

with open(ruta('productos.csv'), 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(['id_producto', 'categoria', 'nombre_producto', 'costo_compra', 'precio_venta'])
    writer.writerows(productos)

# 4. INVENTARIO
inventario = []
id_inv = 1
for loc in regiones:
    for prod in productos:
        stock = random.randint(0, 300)
        inventario.append([id_inv, loc[0], prod[0], stock])
        id_inv += 1

with open(ruta('inventario.csv'), 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(['id_inventario', 'id_local', 'id_producto', 'stock_disponible'])
    writer.writerows(inventario)

# 5 & 6. TRANSACCIONES Y DETALLE
transacciones = []
detalles = []
id_det = 1

# Tipos de pago definidos corporativamente
tipos_pago = ['Credito Tienda', 'Debito', 'Efectivo', ' debito ', 'CREDITO TIENDA']

for id_trans in range(1001, 6001): 
    id_loc = random.randint(1, 16)
    id_cli = random.randint(1, 2000) if random.random() > 0.1 else ID_CLIENTE_ANONIMO
    
    num_items = random.randint(1, 4)
    monto_total = 0
    for _ in range(num_items):
        prod_seleccionado = random.choice(productos)
        id_prod = prod_seleccionado[0]
        precio_vta = prod_seleccionado[4] 
        cantidad = random.randint(1, 3)
        subtotal = round(precio_vta * cantidad, 2)
        
        monto_total += subtotal
        detalles.append([id_det, id_trans, id_prod, cantidad, subtotal])
        id_det += 1
        
    monto_total = round(monto_total, 2)

    # Suciedad intencional: la misma fecha se emite en 4 formatos distintos,
    # como pasa cuando conviven sistemas de distintas épocas.
    # El 10% en texto ('18 mayo 25') antes era un literal fijo: todas las
    # transacciones de ese formato caían el mismo día y deformaban la serie
    # mensual. Ahora se escribe la fecha real en texto, así el defecto sigue
    # siendo un desafío de parsing sin inventar un peak que no existe.
    fecha_obj = datetime(2025, random.randint(1, 12), random.randint(1, 28))
    rand_fmt = random.random()
    if rand_fmt < 0.7: fecha = fecha_obj.strftime('%Y-%m-%d')
    elif rand_fmt < 0.8: fecha = fecha_obj.strftime('%d/%m/%Y')
    elif rand_fmt < 0.9: fecha = fecha_obj.strftime('%d-%m-%Y')
    else: fecha = f"{fecha_obj.day} {MESES_ES[fecha_obj.month - 1]} {fecha_obj.strftime('%y')}"

    # Lógica de cuotas basada en tu sugerencia
    pago = random.choice(tipos_pago)
    if 'credito tiend' in pago.lower():
        cuotas = random.choice([3, 6, 12, 24])
    else:
        cuotas = 1
        
    transacciones.append([id_trans, id_loc, id_cli, fecha, monto_total, pago, cuotas])

with open(ruta('transacciones.csv'), 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(['id_transaccion', 'id_local', 'id_cliente', 'fecha_venta', 'monto_total', 'tipo_pago', 'cantidad_cuotas'])
    writer.writerows(transacciones)

with open(ruta('detalle_transacciones.csv'), 'w', newline='', encoding='utf-8') as f:
    writer = csv.writer(f)
    writer.writerow(['id_detalle', 'id_transaccion', 'id_producto', 'cantidad', 'subtotal'])
    writer.writerows(detalles)

print(f"Listo: 6 CSV escritos en '{OUT}/' con semilla {SEMILLA}.")
print("Recuerda que las cifras publicadas en el README corresponden al dataset")
print("versionado en data/, generado antes de fijar la semilla.")

