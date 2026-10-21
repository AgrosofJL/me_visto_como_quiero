import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'catalogo.dart';
import 'pedido.dart';
import 'prenda.dart';
import 'tema.dart';

/// Un renglón del carrito: una prenda en un talle, con su cantidad.
class ItemCarrito {
  final String prendaId;
  final String nombre;
  final double precio;
  final String? talle;
  final String? imagenUrl;
  int cantidad;

  ItemCarrito({
    required this.prendaId,
    required this.nombre,
    required this.precio,
    this.talle,
    this.imagenUrl,
    this.cantidad = 1,
  });

  factory ItemCarrito.dePrenda(Prenda p, {String? talle, int cantidad = 1}) =>
      ItemCarrito(
        prendaId: p.id ?? p.nombre,
        nombre: p.nombre,
        precio: p.precio,
        talle: talle,
        imagenUrl: p.imagenUrl,
        cantidad: cantidad,
      );

  String get clave => '$prendaId|${talle ?? ''}';
  double get subtotal => precio * cantidad;

  Map<String, dynamic> toJson() => {
        'prendaId': prendaId,
        'nombre': nombre,
        'precio': precio,
        'talle': talle,
        'imagenUrl': imagenUrl,
        'cantidad': cantidad,
      };

  factory ItemCarrito.fromJson(Map<String, dynamic> j) => ItemCarrito(
        prendaId: j['prendaId'] as String,
        nombre: j['nombre'] as String,
        precio: (j['precio'] as num).toDouble(),
        talle: j['talle'] as String?,
        imagenUrl: j['imagenUrl'] as String?,
        cantidad: (j['cantidad'] as num).toInt(),
      );
}

/// Carrito global. Se guarda en el dispositivo para que no se pierda
/// si el cliente cierra la app o recarga la página.
class Carrito extends ChangeNotifier {
  Carrito._();
  static final instancia = Carrito._();
  static const _claveGuardado = 'carrito_v1';

  final List<ItemCarrito> _items = [];
  List<ItemCarrito> get items => List.unmodifiable(_items);

  int get cantidadTotal => _items.fold<int>(0, (s, i) => s + i.cantidad);
  double get total => _items.fold<double>(0, (s, i) => s + i.subtotal);
  bool get vacio => _items.isEmpty;

  Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final texto = prefs.getString(_claveGuardado);
      if (texto == null) return;
      final lista = jsonDecode(texto) as List;
      _items
        ..clear()
        ..addAll(lista.map(
            (e) => ItemCarrito.fromJson(Map<String, dynamic>.from(e as Map))));
      notifyListeners();
    } catch (_) {
      // Si algo guardado está roto, arrancamos con el carrito vacío.
    }
  }

  Future<void> _guardar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _claveGuardado, jsonEncode(_items.map((i) => i.toJson()).toList()));
    } catch (_) {
      // No es grave si no se pudo guardar.
    }
  }

  void agregar(Prenda p, {String? talle, int cantidad = 1}) {
    final nuevo = ItemCarrito.dePrenda(p, talle: talle, cantidad: cantidad);
    final existente = _items.where((i) => i.clave == nuevo.clave).firstOrNull;
    if (existente != null) {
      existente.cantidad += cantidad;
    } else {
      _items.add(nuevo);
    }
    notifyListeners();
    _guardar();
  }

  void cambiarCantidad(ItemCarrito item, int delta) {
    item.cantidad += delta;
    if (item.cantidad <= 0) _items.remove(item);
    notifyListeners();
    _guardar();
  }

  void quitar(ItemCarrito item) {
    _items.remove(item);
    notifyListeners();
    _guardar();
  }

  void vaciar() {
    _items.clear();
    notifyListeners();
    _guardar();
  }
}

final carrito = Carrito.instancia;

/// Ícono de bolsa con la cantidad de prendas.
class BotonCarrito extends StatelessWidget {
  const BotonCarrito({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: carrito,
      builder: (context, _) => IconButton(
        tooltip: 'Mi pedido',
        onPressed: () => abrirCarrito(context),
        icon: Badge(
          isLabelVisible: carrito.cantidadTotal > 0,
          label: Text('${carrito.cantidadTotal}'),
          backgroundColor: Marca.champagne,
          textColor: Marca.negro,
          child: const Icon(Icons.shopping_bag_outlined),
        ),
      ),
    );
  }
}

void abrirCarrito(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CarritoPage()),
  );
}

class CarritoPage extends StatelessWidget {
  const CarritoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FondoMarca(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Mi pedido')),
        body: ListenableBuilder(
          listenable: carrito,
          builder: (context, _) {
            if (carrito.vacio) {
              return Center(
                child: PanelVidrio(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shopping_bag_outlined,
                          size: 48, color: Marca.champagne),
                      const SizedBox(height: 16),
                      Text('Tu pedido está vacío', style: Marca.titulo(28)),
                      const SizedBox(height: 8),
                      const Text('Elegí tus prendas favoritas del catálogo.',
                          style: TextStyle(color: Marca.gris)),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('VER CATÁLOGO'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Centrado(
              maxAncho: 720,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  PanelVidrio(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final item in carrito.items) ...[
                          _RenglonCarrito(item: item),
                          if (item != carrito.items.last)
                            const Divider(indent: 16, endIndent: 16),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  PanelVidrio(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text('TOTAL', style: Marca.etiqueta(size: 13)),
                            const Spacer(),
                            Text(formatearPrecio(carrito.total),
                                style: Marca.titulo(32,
                                    color: Marca.champagne,
                                    peso: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => abrirPedido(
                              context,
                              items: carrito.items,
                              esReserva: false,
                              alEnviar: carrito.vaciar,
                            ),
                            icon: const Icon(Icons.chat_outlined, size: 18),
                            label: const Text('PEDIR POR WHATSAPP'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('SEGUIR COMPRANDO'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () async {
                            final ok = await confirmar(
                                context, 'Vaciar pedido',
                                '¿Querés sacar todas las prendas?');
                            if (ok) carrito.vaciar();
                          },
                          child: const Text('Vaciar pedido',
                              style: TextStyle(color: Marca.gris)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RenglonCarrito extends StatelessWidget {
  const _RenglonCarrito({required this.item});
  final ItemCarrito item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            height: 96,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: FotoPrenda(url: item.imagenUrl),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.nombre,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500)),
                if (item.talle != null) ...[
                  const SizedBox(height: 2),
                  Text('Talle ${item.talle}',
                      style: const TextStyle(color: Marca.gris, fontSize: 13)),
                ],
                const SizedBox(height: 6),
                Text(formatearPrecio(item.subtotal),
                    style: const TextStyle(
                        color: Marca.champagne, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SelectorCantidad(
                  valor: item.cantidad,
                  onMenos: () => carrito.cambiarCantidad(item, -1),
                  onMas: () => carrito.cambiarCantidad(item, 1),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar',
            onPressed: () => carrito.quitar(item),
            icon: const Icon(Icons.close, size: 18, color: Marca.gris),
          ),
        ],
      ),
    );
  }
}

/// Selector de cantidad  [ - 2 + ]
class SelectorCantidad extends StatelessWidget {
  const SelectorCantidad(
      {super.key,
      required this.valor,
      required this.onMenos,
      required this.onMas});
  final int valor;
  final VoidCallback onMenos;
  final VoidCallback onMas;

  @override
  Widget build(BuildContext context) {
    Widget boton(IconData icono, VoidCallback f) => InkWell(
          onTap: f,
          child: SizedBox(
              width: 34, height: 34, child: Icon(icono, size: 16)),
        );
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Marca.borde)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          boton(Icons.remove, onMenos),
          SizedBox(
            width: 32,
            child: Text('$valor',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          boton(Icons.add, onMas),
        ],
      ),
    );
  }
}

Future<bool> confirmar(
    BuildContext context, String titulo, String mensaje) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Aceptar')),
      ],
    ),
  );
  return r == true;
}
