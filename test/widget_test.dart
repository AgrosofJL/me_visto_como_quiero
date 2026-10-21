import 'package:flutter_test/flutter_test.dart';

import 'package:me_visto_como_quiero/prenda.dart';

void main() {
  test('formatea precios en estilo argentino', () {
    expect(formatearPrecio(12500), '\$ 12.500');
    expect(formatearPrecio(999), '\$ 999');
    expect(formatearPrecio(1234567.5), '\$ 1.234.567,50');
  });

  test('lee una prenda desde Supabase', () {
    final p = Prenda.fromMap({
      'id': 'abc',
      'nombre': 'Remera',
      'precio': 15000,
      'talles': ['S', 'M'],
      'disponible': true,
    });
    expect(p.nombre, 'Remera');
    expect(p.precio, 15000);
    expect(p.talles, ['S', 'M']);
  });
}
