// TP Unidad 7 - Food Store - Migración de 5 pedidos a MongoDB
// Fuente: PostgreSQL food_store_tp3 (tablas pedido, detalle_pedido, cliente, producto)
// Ejecutar: mongosh --file migracion_pedidos.js  (o pegar en mongosh)

use('food_store_nosql');

// Colección limpia para re-ejecución idempotente del laboratorio
db.pedidos.drop();

const resultado = db.pedidos.insertMany([
  {
    _id: 1, // id_origen preservado (pedido.id en PostgreSQL)
    id_origen: 1,
    fecha: ISODate("2025-11-27T12:45:09.817Z"),
    forma_pago: "EFECTIVO",
    estado: "ACTIVO", // derivado de pedido.eliminado = false
    total: NumberDecimal("27724.48"),
    cliente: {
      id_origen: 966,
      nombre: "Nombre966",
      apellido: "Apellido966",
      email: "cliente966@foodstore.com"
    },
    lineas: [
      { producto_id: 8,  producto: "Producto 8",  cantidad: 7, precio_unitario: NumberDecimal("4843.57"), subtotal: NumberDecimal("14530.71") },
      { producto_id: 9,  producto: "Producto 9",  cantidad: 2, precio_unitario: NumberDecimal("2274.99"), subtotal: NumberDecimal("9099.96") },
      { producto_id: 10, producto: "Producto 10", cantidad: 9, precio_unitario: NumberDecimal("4093.81"), subtotal: NumberDecimal("4093.81") }
    ]
  },
  {
    _id: 2,
    id_origen: 2,
    fecha: ISODate("2026-03-17T18:21:14.589Z"),
    forma_pago: "TARJETA",
    estado: "ACTIVO",
    total: NumberDecimal("45193.22"),
    cliente: {
      id_origen: 16068,
      nombre: "Nombre16068",
      apellido: "Apellido16068",
      email: "cliente16068@foodstore.com"
    },
    lineas: [
      { producto_id: 15, producto: "Producto 15", cantidad: 3, precio_unitario: NumberDecimal("1828.05"), subtotal: NumberDecimal("9140.25") },
      { producto_id: 16, producto: "Producto 16", cantidad: 5, precio_unitario: NumberDecimal("1998.15"), subtotal: NumberDecimal("13987.05") },
      { producto_id: 17, producto: "Producto 17", cantidad: 6, precio_unitario: NumberDecimal("2758.24"), subtotal: NumberDecimal("22065.92") }
    ]
  },
  {
    _id: 3,
    id_origen: 3,
    fecha: ISODate("2026-08-30T22:31:55.333Z"),
    forma_pago: "TARJETA",
    estado: "ACTIVO",
    total: NumberDecimal("49020.34"),
    cliente: {
      id_origen: 11320,
      nombre: "Nombre11320",
      apellido: "Apellido11320",
      email: "cliente11320@foodstore.com"
    },
    lineas: [
      { producto_id: 22, producto: "Producto 22", cantidad: 1, precio_unitario: NumberDecimal("3153.03"), subtotal: NumberDecimal("25224.24") },
      { producto_id: 23, producto: "Producto 23", cantidad: 4, precio_unitario: NumberDecimal("2719.73"), subtotal: NumberDecimal("5439.46") },
      { producto_id: 24, producto: "Producto 24", cantidad: 6, precio_unitario: NumberDecimal("3059.44"), subtotal: NumberDecimal("18356.64") }
    ]
  },
  {
    _id: 4,
    id_origen: 4,
    fecha: ISODate("2025-09-27T14:08:42.220Z"),
    forma_pago: "EFECTIVO",
    estado: "ACTIVO",
    total: NumberDecimal("21370.25"),
    cliente: {
      id_origen: 5081,
      nombre: "Nombre5081",
      apellido: "Apellido5081",
      email: "cliente5081@foodstore.com"
    },
    lineas: [
      { producto_id: 29, producto: "Producto 29", cantidad: 2, precio_unitario: NumberDecimal("2452.25"), subtotal: NumberDecimal("7356.75") },
      { producto_id: 30, producto: "Producto 30", cantidad: 5, precio_unitario: NumberDecimal("1634.08"), subtotal: NumberDecimal("8170.40") },
      { producto_id: 31, producto: "Producto 31", cantidad: 1, precio_unitario: NumberDecimal("973.85"),  subtotal: NumberDecimal("5843.10") }
    ]
  },
  {
    _id: 5,
    id_origen: 5,
    fecha: ISODate("2026-08-17T12:09:28.141Z"),
    forma_pago: "TRANSFERENCIA",
    estado: "ACTIVO",
    total: NumberDecimal("35496.55"),
    cliente: {
      id_origen: 23,
      nombre: "Nombre23",
      apellido: "Apellido23",
      email: "cliente23@foodstore.com"
    },
    lineas: [
      { producto_id: 36, producto: "Producto 36", cantidad: 7, precio_unitario: NumberDecimal("945.87"),  subtotal: NumberDecimal("4729.35") },
      { producto_id: 37, producto: "Producto 37", cantidad: 1, precio_unitario: NumberDecimal("4741.10"), subtotal: NumberDecimal("9482.20") },
      { producto_id: 38, producto: "Producto 38", cantidad: 1, precio_unitario: NumberDecimal("4257.00"), subtotal: NumberDecimal("21285.00") }
    ]
  }
]);

print("Insertados: " + Object.keys(resultado.insertedIds).length);
printjson(db.pedidos.countDocuments());
