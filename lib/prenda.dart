/// Una prenda del catálogo (una fila de la tabla `prendas` en Supabase).
class Prenda {
  final String? id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String categoria;
  final List<String> talles;

  /// Colores disponibles (vacío = un solo color / no aplica).
  final List<String> colores;
  final String? imagenUrl;
  final String? imagenPath;
  final bool disponible;
  final DateTime? creadoEn;

  /// Stock por talle, ej. {"S": 3, "M": 0}. Vacío = no controla stock.
  final Map<String, int> stock;

  /// Mujer, Hombre, Niños, Unisex o '' (sin definir).
  final String publico;

  /// Rubro al que pertenece (Ropa, Bijouterie...). null = sin rubro.
  final String? rubroId;

  /// Oferta vigente aplicada (se calcula al cargar el catálogo, no se guarda).
  final double? precioOferta;
  final String? ofertaNombre;
  final DateTime? ofertaHasta;

  const Prenda({
    this.id,
    required this.nombre,
    this.descripcion = '',
    this.precio = 0,
    this.categoria = '',
    this.talles = const [],
    this.colores = const [],
    this.imagenUrl,
    this.imagenPath,
    this.disponible = true,
    this.creadoEn,
    this.stock = const {},
    this.publico = '',
    this.rubroId,
    this.precioOferta,
    this.ofertaNombre,
    this.ofertaHasta,
  });

  /// Copia de la prenda con una oferta aplicada.
  Prenda conOferta(double precio, String nombre, DateTime? hasta) => Prenda(
        id: id,
        nombre: this.nombre,
        descripcion: descripcion,
        precio: this.precio,
        categoria: categoria,
        talles: talles,
        colores: colores,
        imagenUrl: imagenUrl,
        imagenPath: imagenPath,
        disponible: disponible,
        creadoEn: creadoEn,
        stock: stock,
        publico: publico,
        rubroId: rubroId,
        precioOferta: precio,
        ofertaNombre: nombre,
        ofertaHasta: hasta,
      );

  factory Prenda.fromMap(Map<String, dynamic> m) => Prenda(
        id: m['id'] as String?,
        nombre: (m['nombre'] ?? '') as String,
        descripcion: (m['descripcion'] ?? '') as String,
        precio: (m['precio'] as num?)?.toDouble() ?? 0,
        categoria: (m['categoria'] ?? '') as String,
        talles: (m['talles'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        colores:
            (m['colores'] as List?)?.map((e) => e.toString()).toList() ??
                const [],
        imagenUrl: m['imagen_url'] as String?,
        imagenPath: m['imagen_path'] as String?,
        disponible: (m['disponible'] ?? true) as bool,
        creadoEn: DateTime.tryParse((m['created_at'] ?? '').toString()),
        stock: {
          for (final e in ((m['stock'] as Map?) ?? const {}).entries)
            e.key.toString(): (e.value as num?)?.toInt() ?? 0,
        },
        publico: (m['publico'] ?? '') as String,
        rubroId: m['rubro_id'] as String?,
      );

  /// Datos para guardar en Supabase (sin el id, que lo genera la base).
  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'categoria': categoria,
        'talles': talles,
        'colores': colores,
        'imagen_url': imagenUrl,
        'imagen_path': imagenPath,
        'disponible': disponible,
        'stock': stock,
        'publico': publico,
        'rubro_id': rubroId,
      };

  /// Precio en formato argentino: $ 12.500 o $ 12.500,50
  String get precioTexto => formatearPrecio(precio);

  /// Está en oferta (con un precio menor al de lista).
  bool get enOferta => precioOferta != null && precioOferta! < precio;

  /// Precio que paga el cliente hoy.
  double get precioFinal => enOferta ? precioOferta! : precio;
  String get precioFinalTexto => formatearPrecio(precioFinal);

  /// % de descuento redondeado (ej. 20).
  int get descuentoPct =>
      enOferta && precio > 0 ? ((1 - precioOferta! / precio) * 100).round() : 0;

  /// Clave de stock de cada combinación talle/color (ej. "XL|Gris").
  static String clave(String? talle, String? color) {
    final t = (talle == null || talle.isEmpty) ? talleUnico : talle;
    return (color == null || color.isEmpty) ? t : '$t|$color';
  }

  List<String> get _tallesOUnico => talles.isEmpty ? const [talleUnico] : talles;

  /// Todas las combinaciones talle/color que llevan stock.
  List<String> get clavesStock => [
        for (final t in _tallesOUnico)
          if (colores.isEmpty)
            clave(t, null)
          else
            for (final c in colores) clave(t, c),
      ];

  bool get controlaStock => stock.isNotEmpty;

  /// Unidades disponibles (null = sin control de stock).
  /// Si no se indica talle o color, suma todas las opciones de ese dato.
  int? stockDe(String? talle, {String? color}) {
    if (!controlaStock) return null;
    var total = 0;
    for (final k in clavesStock) {
      final (t, c) = partesVariante(k);
      final okT = talle == null || talles.isEmpty || t == talle;
      final okC = color == null || colores.isEmpty || c == color;
      if (okT && okC) total += stock[k] ?? 0;
    }
    return total;
  }

  /// Stock de una clave exacta (null = sin control de stock).
  int? stockClave(String k) => controlaStock ? (stock[k] ?? 0) : null;

  int get stockTotal =>
      clavesStock.fold<int>(0, (s, k) => s + (stock[k] ?? 0));

  bool get agotada => controlaStock && stockTotal <= 0;

  bool hayStock(String? talle, {String? color, int cantidad = 1}) {
    final s = stockDe(talle, color: color);
    return s == null || s >= cantidad;
  }

  bool get esNueva =>
      creadoEn != null && DateTime.now().difference(creadoEn!).inDays < 10;
}

const talleUnico = 'Único';

/// "XL|Gris" -> ("XL", "Gris") · "XL" -> ("XL", null)
(String, String?) partesVariante(String clave) {
  final i = clave.indexOf('|');
  return i < 0 ? (clave, null) : (clave.substring(0, i), clave.substring(i + 1));
}

/// Texto para mostrar: "XL · Gris", "Gris", "XL" o "Único".
String etiquetaVariante(String clave) {
  final (t, c) = partesVariante(clave);
  if (c == null) return t;
  return t == talleUnico ? c : '$t · $c';
}

String formatearPrecio(double valor) {
  final entero = valor.truncate();
  final centavos = ((valor - entero) * 100).round();
  final digitos = entero.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digitos[i]);
  }
  final signo = valor < 0 ? '-' : '';
  final dec = centavos > 0 ? ',${centavos.toString().padLeft(2, '0')}' : '';
  return '$signo\$ $buffer$dec';
}
