import 'prenda.dart';

/// Una oferta / promoción que agrupa prendas.
class Oferta {
  final String? id;
  final String nombre;

  /// % de descuento para todas sus prendas (0 si solo usa precios especiales).
  final double descuento;
  final DateTime? desde;
  final DateTime? hasta;
  final bool activa;

  /// prendaId -> precio especial (null = usa el % de descuento).
  final Map<String, double?> prendas;

  const Oferta({
    this.id,
    required this.nombre,
    this.descuento = 0,
    this.desde,
    this.hasta,
    this.activa = true,
    this.prendas = const {},
  });

  factory Oferta.fromMap(Map<String, dynamic> m) => Oferta(
        id: m['id'] as String?,
        nombre: (m['nombre'] ?? '') as String,
        descuento: (m['descuento'] as num?)?.toDouble() ?? 0,
        desde: m['desde'] == null
            ? null
            : DateTime.parse(m['desde'] as String).toLocal(),
        hasta: m['hasta'] == null
            ? null
            : DateTime.parse(m['hasta'] as String).toLocal(),
        activa: (m['activa'] ?? true) as bool,
        prendas: {
          for (final e in (m['oferta_prendas'] as List?) ?? const [])
            (e as Map)['prenda_id'] as String:
                (e['precio_especial'] as num?)?.toDouble(),
        },
      );

  Map<String, dynamic> toMap() => {
        'nombre': nombre,
        'descuento': descuento,
        'desde': desde?.toUtc().toIso8601String(),
        'hasta': hasta?.toUtc().toIso8601String(),
        'activa': activa,
      };

  /// Estado para mostrar en el panel.
  String get estado {
    final ahora = DateTime.now();
    if (!activa) return 'Pausada';
    if (hasta != null && !hasta!.isAfter(ahora)) return 'Vencida';
    if (desde != null && desde!.isAfter(ahora)) return 'Programada';
    return 'Activa';
  }

  bool get vigente => estado == 'Activa';

  /// Precio de la prenda con esta oferta (null si no está incluida).
  double? precioPara(Prenda p) {
    if (p.id == null || !prendas.containsKey(p.id)) return null;
    final especial = prendas[p.id];
    if (especial != null) return especial;
    if (descuento <= 0) return null;
    return redondear(p.precio * (1 - descuento / 100));
  }
}

/// Redondea a la centena (ej. 12.345 -> 12.300) para precios prolijos.
double redondear(double v) => (v / 100).round() * 100.0;

/// Aplica a cada prenda la oferta vigente que le deja el precio más bajo.
List<Prenda> aplicarOfertas(List<Prenda> prendas, List<Oferta> ofertas) {
  final vigentes = ofertas.where((o) => o.vigente).toList();
  if (vigentes.isEmpty) return prendas;
  return [
    for (final p in prendas)
      () {
        Prenda mejor = p;
        for (final o in vigentes) {
          final precio = o.precioPara(p);
          if (precio != null &&
              precio < p.precio &&
              precio < mejor.precioFinal) {
            mejor = p.conOferta(precio, o.nombre, o.hasta);
          }
        }
        return mejor;
      }(),
  ];
}

/// "Termina en 2 d 5 h", "Termina en 3 h", "Termina hoy"...
String? textoVencimiento(DateTime? hasta) {
  if (hasta == null) return null;
  final falta = hasta.difference(DateTime.now());
  if (falta.isNegative) return null;
  if (falta.inDays >= 1) {
    final h = falta.inHours % 24;
    return 'Termina en ${falta.inDays} d${h > 0 ? ' $h h' : ''}';
  }
  if (falta.inHours >= 1) return 'Termina en ${falta.inHours} h';
  return 'Termina en ${falta.inMinutes.clamp(1, 59)} min';
}
