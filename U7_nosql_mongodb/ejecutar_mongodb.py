# Ejecución real de la migración y consultas TP U7 vía pymongo (evidencia)
# Motor: MongoDB local 127.0.0.1:27017
from datetime import datetime, timezone
from decimal import Decimal
from bson.decimal128 import Decimal128
from pymongo import MongoClient
import json

def d(s):
    return Decimal128(Decimal(s))

client = MongoClient("mongodb://127.0.0.1:27017", serverSelectionTimeoutMS=5000)
client.admin.command("ping")
db = client["food_store_nosql"]
db.pedidos.drop()

docs = [
  {"_id":1,"id_origen":1,"fecha":datetime(2025,11,27,12,45,9,817000,tzinfo=timezone.utc),"forma_pago":"EFECTIVO","estado":"ACTIVO","total":d("27724.48"),
   "cliente":{"id_origen":966,"nombre":"Nombre966","apellido":"Apellido966","email":"cliente966@foodstore.com"},
   "lineas":[{"producto_id":8,"producto":"Producto 8","cantidad":7,"precio_unitario":d("4843.57"),"subtotal":d("14530.71")},
             {"producto_id":9,"producto":"Producto 9","cantidad":2,"precio_unitario":d("2274.99"),"subtotal":d("9099.96")},
             {"producto_id":10,"producto":"Producto 10","cantidad":9,"precio_unitario":d("4093.81"),"subtotal":d("4093.81")}]},
  {"_id":2,"id_origen":2,"fecha":datetime(2026,3,17,18,21,14,589000,tzinfo=timezone.utc),"forma_pago":"TARJETA","estado":"ACTIVO","total":d("45193.22"),
   "cliente":{"id_origen":16068,"nombre":"Nombre16068","apellido":"Apellido16068","email":"cliente16068@foodstore.com"},
   "lineas":[{"producto_id":15,"producto":"Producto 15","cantidad":3,"precio_unitario":d("1828.05"),"subtotal":d("9140.25")},
             {"producto_id":16,"producto":"Producto 16","cantidad":5,"precio_unitario":d("1998.15"),"subtotal":d("13987.05")},
             {"producto_id":17,"producto":"Producto 17","cantidad":6,"precio_unitario":d("2758.24"),"subtotal":d("22065.92")}]},
  {"_id":3,"id_origen":3,"fecha":datetime(2026,8,30,22,31,55,333000,tzinfo=timezone.utc),"forma_pago":"TARJETA","estado":"ACTIVO","total":d("49020.34"),
   "cliente":{"id_origen":11320,"nombre":"Nombre11320","apellido":"Apellido11320","email":"cliente11320@foodstore.com"},
   "lineas":[{"producto_id":22,"producto":"Producto 22","cantidad":1,"precio_unitario":d("3153.03"),"subtotal":d("25224.24")},
             {"producto_id":23,"producto":"Producto 23","cantidad":4,"precio_unitario":d("2719.73"),"subtotal":d("5439.46")},
             {"producto_id":24,"producto":"Producto 24","cantidad":6,"precio_unitario":d("3059.44"),"subtotal":d("18356.64")}]},
  {"_id":4,"id_origen":4,"fecha":datetime(2025,9,27,14,8,42,220000,tzinfo=timezone.utc),"forma_pago":"EFECTIVO","estado":"ACTIVO","total":d("21370.25"),
   "cliente":{"id_origen":5081,"nombre":"Nombre5081","apellido":"Apellido5081","email":"cliente5081@foodstore.com"},
   "lineas":[{"producto_id":29,"producto":"Producto 29","cantidad":2,"precio_unitario":d("2452.25"),"subtotal":d("7356.75")},
             {"producto_id":30,"producto":"Producto 30","cantidad":5,"precio_unitario":d("1634.08"),"subtotal":d("8170.40")},
             {"producto_id":31,"producto":"Producto 31","cantidad":1,"precio_unitario":d("973.85"),"subtotal":d("5843.10")}]},
  {"_id":5,"id_origen":5,"fecha":datetime(2026,8,17,12,9,28,141000,tzinfo=timezone.utc),"forma_pago":"TRANSFERENCIA","estado":"ACTIVO","total":d("35496.55"),
   "cliente":{"id_origen":23,"nombre":"Nombre23","apellido":"Apellido23","email":"cliente23@foodstore.com"},
   "lineas":[{"producto_id":36,"producto":"Producto 36","cantidad":7,"precio_unitario":d("945.87"),"subtotal":d("4729.35")},
             {"producto_id":37,"producto":"Producto 37","cantidad":1,"precio_unitario":d("4741.10"),"subtotal":d("9482.20")},
             {"producto_id":38,"producto":"Producto 38","cantidad":1,"precio_unitario":d("4257.00"),"subtotal":d("21285.00")}]},
]
r = db.pedidos.insert_many(docs)
print(f"Conectado a MongoDB {client.server_info()['version']} en 127.0.0.1:27017")
print(f"Base: food_store_nosql | Colección: pedidos | Insertados: {len(r.inserted_ids)} | Total documentos: {db.pedidos.count_documents({})}")

def show(label, cursor):
    rows = list(cursor)
    ids = [x["id_origen"] for x in rows]
    def fmt(o):
        if isinstance(o, Decimal128): return str(o.to_decimal())
        if isinstance(o, datetime): return o.isoformat()
        if isinstance(o, list): return [fmt(i) for i in o]
        if isinstance(o, dict): return {k:fmt(v) for k,v in o.items()}
        return o
    print(f"\n=== {label} ===")
    print(f"Cantidad: {len(rows)} | IDs: {ids}")
    print(json.dumps(fmt(rows), ensure_ascii=False, indent=2))

show("(a) Todos los pedidos: identificador y estado",
     db.pedidos.find({}, {"_id":0,"id_origen":1,"estado":1}).sort("id_origen",1))
show("(b) Pedidos filtrados por estado = ACTIVO (estado seleccionado: ACTIVO)",
     db.pedidos.find({"estado":"ACTIVO"}, {"_id":0,"id_origen":1,"estado":1}).sort("id_origen",1))
show("(c) Pedidos que contienen el producto 'Producto 16' (seleccionado: Producto 16)",
     db.pedidos.find({"lineas.producto":"Producto 16"}, {"_id":0,"id_origen":1,"estado":1,"lineas.$":1}).sort("id_origen",1))
show("(d) Pedidos con total > 30000 (umbral=30000, justif.: separa tickets bajos 1,4 de altos 2,3,5; prom.~35760.93)",
     db.pedidos.find({"total":{"$gt": d("30000")}}, {"_id":0,"id_origen":1,"estado":1,"total":1}).sort("id_origen",1))

client.close()
