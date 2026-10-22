import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'tema.dart';
import 'venta.dart';

/// Tarjeta base del panel de gestión.
class Tarjeta extends StatelessWidget {
  const Tarjeta({
    super.key,
    required this.child,
    this.titulo,
    this.accion,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final String? titulo;
  final Widget? accion;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Marca.superficie,
        border: Border.all(color: Marca.borde),
        borderRadius: BorderRadius.circular(6),
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (titulo != null) ...[
            Row(children: [
              Expanded(
                  child: Text(titulo!.toUpperCase(),
                      style: Marca.etiqueta(color: Marca.champagne))),
              if (accion != null) accion!,
            ]),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// Fila de chips para elegir el período (Hoy, 7 días, Este mes, etc.)
class SelectorPeriodo extends StatelessWidget {
  const SelectorPeriodo(
      {super.key, required this.actual, required this.onCambio});
  final Periodo actual;
  final ValueChanged<Periodo> onCambio;

  Future<void> _personalizado(BuildContext context) async {
    final hoy = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(hoy.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
          start: actual.desde,
          end: actual.hasta.subtract(const Duration(days: 1))),
    );
    if (r != null) {
      onCambio(Periodo('Personalizado', soloDia(r.start),
          soloDia(r.end).add(const Duration(days: 1))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final p in Periodo.rapidos())
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p.nombre,
                    style: TextStyle(
                        color: actual.nombre == p.nombre
                            ? Marca.negro
                            : Marca.marfil)),
                selected: actual.nombre == p.nombre,
                onSelected: (_) => onCambio(p),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 16),
            label: Text(actual.nombre == 'Personalizado'
                ? actual.descripcion
                : 'Elegir fechas'),
            onPressed: () => _personalizado(context),
          ),
        ],
      ),
    );
  }
}

/// Barra horizontal con etiqueta y valor (para rankings y distribuciones).
class BarraValor extends StatelessWidget {
  const BarraValor({
    super.key,
    required this.etiqueta,
    required this.valorTexto,
    required this.proporcion,
    this.detalle,
    this.color = Marca.champagne,
  });
  final String etiqueta;
  final String valorTexto;
  final double proporcion; // 0..1
  final String? detalle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14)),
            ),
            if (detalle != null)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(detalle!,
                    style: const TextStyle(color: Marca.gris, fontSize: 12)),
              ),
            Text(valorTexto,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: proporcion.isFinite ? proporcion.clamp(0.0, 1.0) : 0,
              minHeight: 6,
              color: color,
              backgroundColor: Marca.superficieAlta,
            ),
          ),
        ],
      ),
    );
  }
}

/// Texto gris centrado para estados vacíos.
class SinDatos extends StatelessWidget {
  const SinDatos(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Marca.gris)),
        ),
      );
}

/// Mensaje de error amigable a partir de una excepción de Supabase.
String mensajeError(Object e) {
  if (e is PostgrestException) return e.message;
  if (e is AuthException) return e.message;
  final t = e.toString();
  final m = RegExp(r'message: ([^,]+)').firstMatch(t);
  return m != null ? m.group(1)!.trim() : t;
}

void avisar(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(texto)));
}
