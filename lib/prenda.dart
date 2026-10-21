/// Una prenda del catálogo (una fila de la tabla `prendas` en Supabase).
class Prenda {
  final String? id;
  final String nombre;
  final String descripcion;
  final double precio;
  final String categoria;
  final List<String> talles;
  final String? imagenUrl;
  final String? imagenPath;
  final bool disponible;
  final DateTime? creadoEn;

  const Prenda({
    this.id,
    required this.nombre,
    this.descripcion = '',
    this.precio = 0,
    this.categoria = '',
    this.talles = const [],
    this.imagenUrl,
    this.imagenPath,
    this.disponible = true,
    this.creadoEn,
  });

  factory Prenda.fromMap(Map<String, dynamic> m) => Prenda(
        id: m['id'] as String?,
        nombre: (m['nombre'] ?? '') as String,
        descripcion: (m['descripcion'] ?? '') as String,
        precio: (m['precio'] as num?)?.toDouble() ?? 0,
        categoria: (m['categoria'] ?? '') as String,
        talles: (m['talles'] as List?)?.map((e) => e.toString()).toList() ??
            const [],
        imagenUrl: m['imagen_url'] as String?,
        imagenPath: m['imagen_path'] as String?,
        disponible: (m['disponible'] ?? true) as bool,
        creadoEn: DateTime.tryParse((m['created_at'] ?? '').toString()),
      );

  /// Datos para guardar en Supabase (sin el id, que lo genera la base).
  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio,
        'categoria': categoria,
        'talles': talles,
        'imagen_url': imagenUrl,
        'imagen_path': imagenPath,
        'disponible': disponible,
      };

  /// Precio en formato argentino: $ 12.500 o $ 12.500,50
  String get precioTexto => formatearPrecio(precio);

  /// Cargada en los últimos 10 días: se muestra la etiqueta "NUEVO".
  bool get esNueva =>
      creadoEn != null && DateTime.now().difference(creadoEn!).inDays < 10;
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
