import 'prenda.dart';

/// Un renglón de una venta.
class ItemVenta {
  final String? prendaId;
  final String nombre;
  final String categoria;
  final String talle;
  final int cantidad;
  final double precioUnitario;
  final double costoUnitario;

  const ItemVenta({
    required this.prendaId,
    required this.nombre,
    this.categoria = '',
    this.talle = talleUnico,
    required this.cantidad,
    required this.precioUnitario,
    this.costoUnitario = 0,
  });

  double get subtotal => precioUnitario * cantidad;
  double get costo => costoUnitario * cantidad;

  factory ItemVenta.fromMap(Map<String, dynamic> m) => ItemVenta(
        prendaId: m['prenda_id'] as String?,
        nombre: (m['nombre'] ?? '') as String,
        categoria: (m['categoria'] ?? '') as String,
        talle: (m['talle'] ?? talleUnico) as String,
        cantidad: (m['cantidad'] as num).toInt(),
        precioUnitario: (m['precio_unitario'] as num).toDouble(),
        costoUnitario: (m['costo_unitario'] as num?)?.toDouble() ?? 0,
      );

  /// Formato que espera la función registrar_venta de Supabase.
  Map<String, dynamic> toRpc() => {
        'prenda_id': prendaId,
        'talle': talle,
        'cantidad': cantidad,
        'precio': precioUnitario,
      };
}

/// Una venta (ticket) con sus renglones.
class Venta {
  final String id;
  final int numero;
  final DateTime fecha;
  final String cliente;
  final String formaPago;
  final String canal;
  final String nota;
  final double total;
  final double costoTotal;
  final bool anulada;
  final String? creadaPor;
  final List<ItemVenta> items;

  const Venta({
    required this.id,
    required this.numero,
    required this.fecha,
    this.cliente = '',
    this.formaPago = '',
    this.canal = '',
    this.nota = '',
    this.total = 0,
    this.costoTotal = 0,
    this.anulada = false,
    this.creadaPor,
    this.items = const [],
  });

  double get ganancia => total - costoTotal;
  int get unidades => items.fold<int>(0, (s, i) => s + i.cantidad);

  factory Venta.fromMap(Map<String, dynamic> m) => Venta(
        id: m['id'] as String,
        numero: (m['numero'] as num).toInt(),
        fecha: DateTime.parse(m['fecha'] as String).toLocal(),
        cliente: (m['cliente'] ?? '') as String,
        formaPago: (m['forma_pago'] ?? '') as String,
        canal: (m['canal'] ?? '') as String,
        nota: (m['nota'] ?? '') as String,
        total: (m['total'] as num?)?.toDouble() ?? 0,
        costoTotal: (m['costo_total'] as num?)?.toDouble() ?? 0,
        anulada: (m['anulada'] ?? false) as bool,
        creadaPor: m['creada_por'] as String?,
        items: ((m['venta_items'] as List?) ?? const [])
            .map((e) => ItemVenta.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

// ---------------- Fechas ----------------

String dosDigitos(int n) => n.toString().padLeft(2, '0');

String fechaDiaMes(DateTime d) => '${dosDigitos(d.day)}/${dosDigitos(d.month)}';

String fechaCompleta(DateTime d) =>
    '${dosDigitos(d.day)}/${dosDigitos(d.month)}/${d.year}';

String horaMinutos(DateTime d) => '${dosDigitos(d.hour)}:${dosDigitos(d.minute)}';

DateTime soloDia(DateTime d) => DateTime(d.year, d.month, d.day);

/// Rango de fechas [desde, hasta) con un nombre para mostrar.
class Periodo {
  final String nombre;
  final DateTime desde;
  final DateTime hasta;
  const Periodo(this.nombre, this.desde, this.hasta);

  int get dias => hasta.difference(desde).inDays.clamp(1, 100000);

  /// El período inmediatamente anterior, de la misma duración.
  Periodo get anterior =>
      Periodo('Anterior', desde.subtract(Duration(days: dias)), desde);

  static Periodo hoy() {
    final h = soloDia(DateTime.now());
    return Periodo('Hoy', h, h.add(const Duration(days: 1)));
  }

  static Periodo ayer() {
    final h = soloDia(DateTime.now());
    return Periodo('Ayer', h.subtract(const Duration(days: 1)), h);
  }

  static Periodo ultimos(int n) {
    final manana = soloDia(DateTime.now()).add(const Duration(days: 1));
    return Periodo('$n días', manana.subtract(Duration(days: n)), manana);
  }

  static Periodo esteMes() {
    final h = DateTime.now();
    return Periodo('Este mes', DateTime(h.year, h.month, 1),
        DateTime(h.year, h.month + 1, 1));
  }

  static Periodo mesPasado() {
    final h = DateTime.now();
    return Periodo('Mes pasado', DateTime(h.year, h.month - 1, 1),
        DateTime(h.year, h.month, 1));
  }

  static Periodo esteAnio() {
    final h = DateTime.now();
    return Periodo('Este año', DateTime(h.year, 1, 1), DateTime(h.year + 1, 1, 1));
  }

  static List<Periodo> rapidos() => [
        hoy(),
        ayer(),
        ultimos(7),
        ultimos(30),
        esteMes(),
        mesPasado(),
        esteAnio(),
      ];

  String get descripcion {
    final ultimo = hasta.subtract(const Duration(days: 1));
    return soloDia(desde) == soloDia(ultimo)
        ? fechaCompleta(desde)
        : '${fechaCompleta(desde)} al ${fechaCompleta(ultimo)}';
  }
}
