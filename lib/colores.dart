import 'package:flutter/material.dart';

/// Colores rápidos para cargar en las prendas (se pueden agregar otros a mano).
const coloresRapidos = [
  'Negro',
  'Blanco',
  'Gris',
  'Azul',
  'Celeste',
  'Rojo',
  'Bordó',
  'Rosa',
  'Verde',
  'Beige',
  'Marrón',
  'Amarillo',
  'Naranja',
  'Lila',
];

const _muestras = <String, Color>{
  'negro': Color(0xFF111111),
  'blanco': Color(0xFFF7F7F7),
  'gris': Color(0xFF8E8E8E),
  'gris claro': Color(0xFFC8C8C8),
  'gris oscuro': Color(0xFF4A4A4A),
  'azul': Color(0xFF1F3A8A),
  'azul marino': Color(0xFF14213D),
  'celeste': Color(0xFF7EC8E3),
  'rojo': Color(0xFFC62828),
  'bordo': Color(0xFF6D1A2A),
  'rosa': Color(0xFFF2A7C3),
  'fucsia': Color(0xFFD81B60),
  'verde': Color(0xFF2E7D32),
  'verde militar': Color(0xFF4B5320),
  'beige': Color(0xFFD9C8A9),
  'crema': Color(0xFFF3E9D2),
  'marron': Color(0xFF6D4C41),
  'camel': Color(0xFFC19A6B),
  'amarillo': Color(0xFFF9D648),
  'naranja': Color(0xFFF57C00),
  'lila': Color(0xFFB39DDB),
  'violeta': Color(0xFF6A1B9A),
  'dorado': Color(0xFFD4AF37),
  'plateado': Color(0xFFC0C0C0),
};

String _normalizar(String s) => s
    .toLowerCase()
    .trim()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');

/// Color para mostrar el puntito; null si no lo conocemos (ej. "Estampado").
Color? muestraDeColor(String nombre) => _muestras[_normalizar(nombre)];

/// "azul marino" -> "Azul marino"
String capitalizarColor(String s) {
  final t = s.trim();
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1).toLowerCase();
}

/// Circulito con el color (o un ícono si es un color desconocido).
class PuntoColor extends StatelessWidget {
  const PuntoColor(this.nombre, {super.key, this.tamano = 14});
  final String nombre;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final c = muestraDeColor(nombre);
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0x66FFFFFF)),
        gradient: c == null
            ? const SweepGradient(colors: [
                Colors.red,
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.purple,
                Colors.red,
              ])
            : null,
      ),
    );
  }
}
