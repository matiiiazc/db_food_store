// TP Unidad 7 - Food Store - Consultas en MongoDB (Parte 2)
// Ejecutar tras migracion_pedidos.js: mongosh --file consultas_mongodb.js

use('food_store_nosql');

print("\n=== (a) Todos los pedidos: identificador y estado ===");
printjson(db.pedidos.find(
  {},
  { _id: 0, id_origen: 1, estado: 1 }
).sort({ id_origen: 1 }).toArray());

print("\n=== (b) Pedidos filtrados por estado = ACTIVO ===");
const estadoSel = "ACTIVO";
const resB = db.pedidos.find(
  { estado: estadoSel },
  { _id: 0, id_origen: 1, estado: 1 }
).sort({ id_origen: 1 }).toArray();
print("Estado seleccionado: " + estadoSel + " | Cantidad: " + resB.length);
print("IDs: " + resB.map(p => p.id_origen).join(", "));
printjson(resB);

print("\n=== (c) Pedidos que contienen el producto 'Producto 16' ===");
const productoSel = "Producto 16"; // también podría buscarse por lineas.producto_id: 16
const resC = db.pedidos.find(
  { "lineas.producto": productoSel },
  { _id: 0, id_origen: 1, estado: 1, "lineas.$": 1 }
).sort({ id_origen: 1 }).toArray();
print("Producto seleccionado: " + productoSel + " | Cantidad: " + resC.length);
print("IDs: " + resC.map(p => p.id_origen).join(", "));
printjson(resC);

print("\n=== (d) Pedidos cuyo total es superior a un umbral ===");
// Umbral = 30000. Justificación: separa pedidos de ticket alto de los de ticket bajo
// dentro del subconjunto migrado (totales: 27724.48, 45193.22, 49020.34, 21370.25, 35496.55;
// promedio ~35760). Un umbral de 30000 deja fuera los dos pedidos menores y conserva los tres
// de mayor valor, útil para análisis comercial de tickets altos.
const umbral = NumberDecimal("30000");
const resD = db.pedidos.find(
  { total: { $gt: umbral } },
  { _id: 0, id_origen: 1, estado: 1, total: 1 }
).sort({ id_origen: 1 }).toArray();
print("Umbral: 30000 | Cantidad: " + resD.length);
print("IDs: " + resD.map(p => p.id_origen).join(", "));
printjson(resD);
