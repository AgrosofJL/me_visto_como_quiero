import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'carrito.dart';
import 'config.dart';
import 'prenda.dart';
import 'tema.dart';

const _dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const _diasCorto = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
const _meses = ['ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC'];

String fechaLarga(DateTime d) =>
    '${_dias[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Abre el formulario para confirmar el pedido o la reserva.
/// [alEnviar] se llama después de abrir WhatsApp (ej. para vaciar el carrito).
void abrirPedido(
  BuildContext context, {
  required List<ItemCarrito> items,
  required bool esReserva,
  VoidCallback? alEnviar,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PedidoPage(
        items: List.of(items),
        esReserva: esReserva,
        alEnviar: alEnviar,
      ),
    ),
  );
}

class PedidoPage extends StatefulWidget {
  const PedidoPage({
    super.key,
    required this.items,
    required this.esReserva,
    this.alEnviar,
  });
  final List<ItemCarrito> items;
  final bool esReserva;
  final VoidCallback? alEnviar;

  @override
  State<PedidoPage> createState() => _PedidoPageState();
}

class _PedidoPageState extends State<PedidoPage> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _direccion = TextEditingController();
  final _nota = TextEditingController();

  bool _envio = false;
  DateTime? _fecha;
  String? _franja;
  String _pago = Config.formasDePago.first;
  String? _error;

  late final List<DateTime> _proximosDias = _calcularDias();

  @override
  void initState() {
    super.initState();
    _recordarCliente();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _direccion.dispose();
    _nota.dispose();
    super.dispose();
  }

  List<DateTime> _calcularDias() {
    final hoy = DateTime.now();
    final base = DateTime(hoy.year, hoy.month, hoy.day);
    return [
      for (var i = 0; i <= Config.diasMaxReserva; i++)
        base.add(Duration(days: i)),
    ].where((d) => !Config.diasCerrado.contains(d.weekday)).toList();
  }

  Future<void> _recordarCliente() async {
    try {
      final p = await SharedPreferences.getInstance();
      _nombre.text = p.getString('cliente_nombre') ?? '';
      _direccion.text = p.getString('cliente_direccion') ?? '';
    } catch (_) {
      // Primera vez o almacenamiento no disponible.
    }
  }

  Future<void> _guardarCliente() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('cliente_nombre', _nombre.text.trim());
      await p.setString('cliente_direccion', _direccion.text.trim());
    } catch (_) {
      // No es grave.
    }
  }

  double get _total => widget.items.fold<double>(0, (s, i) => s + i.subtotal);

  String _armarMensaje() {
    final b = StringBuffer();
    b.writeln(widget.esReserva
        ? '¡Hola ${Config.nombreTienda}! 👋 Quiero *reservar*:'
        : '¡Hola ${Config.nombreTienda}! 👋 Quiero hacer este *pedido*:');
    b.writeln();
    for (final i in widget.items) {
      final talle = i.variante != null ? ' (${i.variante})' : '';
      b.writeln('• ${i.cantidad} x ${i.nombre}$talle — ${formatearPrecio(i.subtotal)}');
    }
    b.writeln();
    b.writeln('*Total: ${formatearPrecio(_total)}*');
    b.writeln();
    b.writeln('📅 Día: ${fechaLarga(_fecha!)}');
    b.writeln('🕐 Horario: $_franja');
    b.writeln(_envio
        ? '🚚 Entrega: Envío a domicilio — ${_direccion.text.trim()}'
        : '🏬 Entrega: Retiro en el local (${Config.linkMapa})');
    b.writeln('💳 Pago: $_pago');
    b.writeln('👤 Nombre: ${_nombre.text.trim()}');
    if (_nota.text.trim().isNotEmpty) b.writeln('📝 Nota: ${_nota.text.trim()}');
    return b.toString().trim();
  }

  Future<void> _enviar() async {
    setState(() => _error = null);
    final formOk = _form.currentState!.validate();
    if (_fecha == null) {
      setState(() => _error = 'Elegí el día');
      return;
    }
    if (_franja == null) {
      setState(() => _error = 'Elegí el horario');
      return;
    }
    if (!formOk) return;

    await _guardarCliente();
    final uri = Uri.https(
        'wa.me', '/${Config.whatsapp}', {'text': _armarMensaje()});
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp')));
      return;
    }
    widget.alEnviar?.call();
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline,
            color: Marca.champagne, size: 48),
        title: Text('¡Listo!', style: Marca.titulo(32)),
        content: const Text(
          'Te abrimos WhatsApp con tu pedido armado. '
          'Solo tocá "Enviar" y te confirmamos a la brevedad.',
          textAlign: TextAlign.center,
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('VOLVER A LA TIENDA')),
        ],
      ),
    );
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.esReserva ? 'Reservar' : 'Finalizar pedido';

    return FondoMarca(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text(titulo)),
        body: Form(
          key: _form,
          child: Centrado(
            maxAncho: 720,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _resumen(),
                const SizedBox(height: 16),
                _seccion('1 · ¿CUÁNDO?', [
                  Text('Día', style: Marca.titulo(22)),
                  const SizedBox(height: 10),
                  _selectorDia(),
                  const SizedBox(height: 20),
                  Text('Horario', style: Marca.titulo(22)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in Config.franjasHorarias)
                        _chip(f, _franja == f,
                            () => setState(() => _franja = f)),
                    ],
                  ),
                ]),
                const SizedBox(height: 16),
                _seccion('2 · ENTREGA Y PAGO', [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _chip('Retiro en el local', !_envio,
                        () => setState(() => _envio = false)),
                    if (Config.ofreceEnvio)
                      _chip('Envío a domicilio', _envio,
                          () => setState(() => _envio = true)),
                  ]),
                  if (_envio) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _direccion,
                      decoration: const InputDecoration(
                          labelText: 'Dirección de entrega *'),
                      validator: (v) => _envio && (v ?? '').trim().isEmpty
                          ? 'Poné la dirección'
                          : null,
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: abrirMapa,
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      icon: const Icon(Icons.place_outlined, size: 18),
                      label: const Text(
                          '${Config.direccion} · Ver en el mapa'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Forma de pago', style: Marca.titulo(22)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final p in Config.formasDePago)
                      _chip(p, _pago == p, () => setState(() => _pago = p)),
                  ]),
                  if (_pago == 'Transferencia' &&
                      Config.aliasTransferencia.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const SelectableText(
                        'Alias: ${Config.aliasTransferencia}',
                        style: TextStyle(color: Marca.champagne)),
                  ],
                ]),
                const SizedBox(height: 16),
                _seccion('3 · TUS DATOS', [
                  TextFormField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.words,
                    decoration:
                        const InputDecoration(labelText: 'Nombre y apellido *'),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Poné tu nombre' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nota,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        labelText: 'Comentario (opcional)',
                        hintText: 'Ej: es para regalo'),
                  ),
                ]),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Marca.whatsapp,
                      foregroundColor: Colors.white),
                  onPressed: _enviar,
                  icon: const Icon(Icons.chat, size: 20),
                  label: Text(widget.esReserva
                      ? 'ENVIAR RESERVA POR WHATSAPP'
                      : 'ENVIAR PEDIDO POR WHATSAPP'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'No se cobra nada ahora. Coordinamos el pago al confirmar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Marca.gris, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resumen() => PanelVidrio(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TU SELECCIÓN', style: Marca.etiqueta()),
            const SizedBox(height: 12),
            for (final i in widget.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${i.cantidad} × ${i.nombre}'
                        '${i.variante != null ? ' · ${i.variante}' : ''}',
                      ),
                    ),
                    Text(formatearPrecio(i.subtotal)),
                  ],
                ),
              ),
            const Divider(height: 20),
            Row(
              children: [
                Text('TOTAL', style: Marca.etiqueta(size: 12)),
                const Spacer(),
                Text(formatearPrecio(_total),
                    style: Marca.titulo(28,
                        color: Marca.champagne, peso: FontWeight.w600)),
              ],
            ),
          ],
        ),
      );

  Widget _seccion(String titulo, List<Widget> hijos) => PanelVidrio(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: Marca.etiqueta(color: Marca.champagne)),
            const SizedBox(height: 14),
            ...hijos,
          ],
        ),
      );

  Widget _chip(String texto, bool sel, VoidCallback onTap) => ChoiceChip(
        label: Text(texto,
            style: TextStyle(color: sel ? Marca.negro : Marca.marfil)),
        selected: sel,
        onSelected: (_) => onTap(),
      );

  Widget _selectorDia() {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _proximosDias.length,
        separatorBuilder: (context, i) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = _proximosDias[i];
          final sel = _fecha == d;
          final esHoy = i == 0 && d.day == DateTime.now().day;
          return InkWell(
            onTap: () => setState(() => _fecha = d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 64,
              decoration: BoxDecoration(
                color: sel ? Marca.marfil : Colors.transparent,
                border: Border.all(color: sel ? Marca.marfil : Marca.borde),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(esHoy ? 'HOY' : _diasCorto[d.weekday - 1],
                      style: Marca.etiqueta(
                          size: 10, color: sel ? Marca.negro : Marca.gris)),
                  const SizedBox(height: 2),
                  Text('${d.day}',
                      style: Marca.titulo(26,
                          peso: FontWeight.w600,
                          color: sel ? Marca.negro : Marca.marfil)),
                  Text(_meses[d.month - 1],
                      style: Marca.etiqueta(
                          size: 9, color: sel ? Marca.negro : Marca.gris)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Atajo para reservar una sola prenda sin pasar por el carrito.
void reservarAhora(BuildContext context, Prenda p,
    {String? talle, String? color, int cantidad = 1}) {
  abrirPedido(
    context,
    items: [
      ItemCarrito.dePrenda(p, talle: talle, color: color, cantidad: cantidad)
    ],
    esReserva: true,
  );
}
