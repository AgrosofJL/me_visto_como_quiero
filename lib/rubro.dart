/// Tipo de producto que vende la tienda (Ropa, Bijouterie, Ropa interior...).
class Rubro {
  final String? id;
  final String nombre;
  final int orden;

  const Rubro({this.id, required this.nombre, this.orden = 0});

  factory Rubro.fromMap(Map<String, dynamic> m) => Rubro(
        id: m['id'] as String?,
        nombre: (m['nombre'] ?? '') as String,
        orden: (m['orden'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {'nombre': nombre, 'orden': orden};
}
