import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'carrito.dart' show SelectorCantidad, confirmar;
import 'catalogo.dart' show FotoPrenda;
import 'colores.dart';
import 'config.dart';
import 'prenda.dart';
import 'servicio.dart';
import 'tema.dart';
import 'venta.dart';

// =====================================================================
// Listado de ventas
// =====================================================================

class VentasTab extends StatefulWidget {
  const VentasTab({super.key});

  @override
  State<VentasTab> createState() => VentasTabState();
}

class VentasTabState extends State<VentasTab> {
  Periodo _periodo = Periodo.hoy();
  List<Venta> _ventas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  Future<void> recargar() async {
    setState(() => _cargando = true);
    try {
      _ventas = await Servicio.listarVentas(_periodo.desde, _periodo.hasta);
    } catch (e) {
      if (mounted) avisar(context, 'No se pudieron cargar las ventas: ${mensajeError(e)}');
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _verDetalle(Venta v) async {
    final anulo = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleVenta(venta: v),
    );
    if (anulo == true) recargar();
  }

  @override
  Widget build(BuildContext context) {
    final validas = _ventas.where((v) => !v.anulada).toList();
    final total = validas.fold<double>(0, (s, v) => s + v.total);
    final unidades = validas.fold<int>(0, (s, v) => s + v.unidades);

    // Agrupar por día
    final porDia = <DateTime, List<Venta>>{};
    for (final v in _ventas) {
      porDia.putIfAbsent(soloDia(v.fecha), () => []).add(v);
    }

    return RefreshIndicator(
      onRefresh: recargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          SelectorPeriodo(
            actual: _periodo,
            onCambio: (p) {
              _periodo = p;
              recargar();
            },
          ),
          const SizedBox(height: 14),
          Tarjeta(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_periodo.descripcion.toUpperCase(),
                          style: Marca.etiqueta()),
                      const SizedBox(height: 6),
                      Text(formatearPrecio(total),
                          style: Marca.titulo(36,
                              color: Marca.champagne, peso: FontWeight.w600)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${validas.length} ventas'),
                    Text('$unidades prendas',
                        style: const TextStyle(color: Marca.gris)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child: CircularProgressIndicator(color: Marca.champagne)),
            )
          else if (_ventas.isEmpty)
            const SinDatos('No hay ventas en este período.\n'
                'Tocá "Nueva venta" para registrar una.')
          else
            for (final dia in porDia.keys) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                child: Row(children: [
                  Text(_nombreDia(dia), style: Marca.titulo(22)),
                  const Spacer(),
                  Text(
                      formatearPrecio(porDia[dia]!
                          .where((v) => !v.anulada)
                          .fold<double>(0, (s, v) => s + v.total)),
                      style: const TextStyle(color: Marca.gris)),
                ]),
              ),
              Tarjeta(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final v in porDia[dia]!) ...[
                    _FilaVenta(venta: v, onTap: () => _verDetalle(v)),
                    if (v != porDia[dia]!.last) const Divider(),
                  ],
                ]),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  String _nombreDia(DateTime d) {
    final hoy = soloDia(DateTime.now());
    if (d == hoy) return 'Hoy';
    if (d == hoy.subtract(const Duration(days: 1))) return 'Ayer';
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return '${dias[d.weekday - 1]} ${fechaDiaMes(d)}';
  }
}

class _FilaVenta extends StatelessWidget {
  const _FilaVenta({required this.venta, required this.onTap});
  final Venta venta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = venta;
    final resumen = v.items
        .map((i) => '${i.cantidad}× ${i.nombre}'
            '${i.talle != talleUnico ? ' (${etiquetaVariante(i.talle)})' : ''}')
        .join(', ');
    final tachado = v.anulada
        ? const TextStyle(
            decoration: TextDecoration.lineThrough, color: Marca.gris)
        : null;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: Marca.superficieAlta,
        child: Text('#${v.numero}',
            style: const TextStyle(fontSize: 11, color: Marca.marfil)),
      ),
      title: Text(resumen,
          maxLines: 1, overflow: TextOverflow.ellipsis, style: tachado),
      subtitle: Text(
        [
          horaMinutos(v.fecha),
          v.formaPago,
          if (v.canal.isNotEmpty) v.canal,
          if (v.cliente.isNotEmpty) v.cliente,
          if (v.anulada) 'ANULADA',
        ].join(' · '),
        style: const TextStyle(color: Marca.gris, fontSize: 12),
      ),
      trailing: Text(formatearPrecio(v.total),
          style: (tachado ?? const TextStyle())
              .copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

class _DetalleVenta extends StatefulWidget {
  const _DetalleVenta({required this.venta});
  final Venta venta;

  @override
  State<_DetalleVenta> createState() => _DetalleVentaState();
}

class _DetalleVentaState extends State<_DetalleVenta> {
  bool _anulando = false;

  Future<void> _anular() async {
    final ok = await confirmar(context, 'Anular venta',
        'Se devuelve el stock y la venta deja de sumar en los totales. ¿Seguro?');
    if (!ok) return;
    setState(() => _anulando = true);
    try {
      await Servicio.anularVenta(widget.venta.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        avisar(context, mensajeError(e));
        setState(() => _anulando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.venta;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text('Venta #${v.numero}', style: Marca.titulo(30)),
              const Spacer(),
              if (v.anulada)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Theme.of(context).colorScheme.error,
                  child: Text('ANULADA',
                      style: Marca.etiqueta(color: Marca.negro, size: 10)),
                ),
            ]),
            const SizedBox(height: 4),
            Text(
              '${fechaCompleta(v.fecha)} ${horaMinutos(v.fecha)} · ${v.formaPago} · ${v.canal}',
              style: const TextStyle(color: Marca.gris),
            ),
            if (v.cliente.isNotEmpty) Text('Cliente: ${v.cliente}'),
            if (v.nota.isNotEmpty)
              Text('Nota: ${v.nota}', style: const TextStyle(color: Marca.gris)),
            const SizedBox(height: 16),
            for (final i in v.items)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        '${i.cantidad} × ${i.nombre}'
                        '${i.talle != talleUnico ? ' · ${etiquetaVariante(i.talle)}' : ''}'
                        '\n${formatearPrecio(i.precioUnitario)} c/u'),
                  ),
                  Text(formatearPrecio(i.subtotal),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
            const Divider(height: 24),
            _linea('Total', formatearPrecio(v.total), grande: true),
            if (v.costoTotal > 0) ...[
              _linea('Costo', formatearPrecio(v.costoTotal)),
              _linea('Ganancia', formatearPrecio(v.ganancia)),
            ],
            if (v.creadaPor != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Registrada por ${v.creadaPor}',
                    style: const TextStyle(color: Marca.gris, fontSize: 12)),
              ),
            const SizedBox(height: 20),
            if (!v.anulada)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.error),
                  ),
                  onPressed: _anulando ? null : _anular,
                  icon: const Icon(Icons.undo),
                  label: const Text('ANULAR VENTA Y DEVOLVER STOCK'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _linea(String a, String b, {bool grande = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(children: [
          Text(a, style: const TextStyle(color: Marca.gris)),
          const Spacer(),
          Text(b,
              style: grande
                  ? Marca.titulo(28,
                      color: Marca.champagne, peso: FontWeight.w600)
                  : null),
        ]),
      );
}

// =====================================================================
// Nueva venta
// =====================================================================

class NuevaVentaPage extends StatefulWidget {
  const NuevaVentaPage({super.key, this.prendaInicial});

  /// Si viene desde "Vender" en una prenda, se abre directo para esa prenda.
  final Prenda? prendaInicial;

  @override
  State<NuevaVentaPage> createState() => _NuevaVentaPageState();
}

class _NuevaVentaPageState extends State<NuevaVentaPage> {
  List<Prenda> _prendas = [];
  final List<ItemVenta> _items = [];
  String _pago = Config.formasDePagoVenta.first;
  String _canal = Config.canalesVenta.first;
  final _cliente = TextEditingController();
  final _nota = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _cliente.dispose();
    _nota.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      _prendas = await Servicio.catalogo();
      if (mounted) setState(() {});
    } catch (_) {
      // Se puede reintentar al tocar "Agregar prenda".
    }
    if (widget.prendaInicial != null && mounted) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _elegirDetalle(widget.prendaInicial!));
    }
  }

  double get _total => _items.fold<double>(0, (s, i) => s + i.subtotal);

  /// Cuántas unidades de ese talle ya están en este ticket.
  int _enTicket(String? prendaId, String talle) => _items
      .where((i) => i.prendaId == prendaId && i.talle == talle)
      .fold<int>(0, (s, i) => s + i.cantidad);

  Future<void> _buscarPrenda() async {
    if (_prendas.isEmpty) await _cargar();
    if (!mounted) return;
    final p = await showModalBottomSheet<Prenda>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BuscadorPrendas(prendas: _prendas),
    );
    if (p != null) _elegirDetalle(p);
  }

  Future<void> _elegirDetalle(Prenda p) async {
    final item = await showModalBottomSheet<ItemVenta>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DetalleItem(
        prenda: p,
        yaEnTicket: (talle) => _enTicket(p.id, talle),
      ),
    );
    if (item != null) setState(() => _items.add(item));
  }

  Future<void> _confirmar() async {
    if (_items.isEmpty) {
      avisar(context, 'Agregá al menos una prenda');
      return;
    }
    setState(() => _guardando = true);
    try {
      await Servicio.registrarVenta(
        items: _items,
        formaPago: _pago,
        canal: _canal,
        cliente: _cliente.text.trim(),
        nota: _nota.text.trim(),
      );
      if (!mounted) return;
      avisar(context, 'Venta registrada · ${formatearPrecio(_total)}');
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        avisar(context, mensajeError(e));
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva venta')),
      body: Centrado(
        maxAncho: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Tarjeta(
              titulo: 'Prendas',
              accion: TextButton.icon(
                onPressed: _buscarPrenda,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Agregar'),
              ),
              child: _items.isEmpty
                  ? InkWell(
                      onTap: _buscarPrenda,
                      child: const SinDatos(
                          'Tocá "Agregar" para elegir la prenda vendida'),
                    )
                  : Column(children: [
                      for (var k = 0; k < _items.length; k++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_items[k].nombre),
                          subtitle: Text(
                            '${_items[k].talle != talleUnico ? '${etiquetaVariante(_items[k].talle)} · ' : ''}'
                            '${_items[k].cantidad} × ${formatearPrecio(_items[k].precioUnitario)}',
                            style: const TextStyle(color: Marca.gris),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(formatearPrecio(_items[k].subtotal),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              IconButton(
                                tooltip: 'Quitar',
                                onPressed: () =>
                                    setState(() => _items.removeAt(k)),
                                icon: const Icon(Icons.close,
                                    size: 18, color: Marca.gris),
                              ),
                            ],
                          ),
                        ),
                    ]),
            ),
            const SizedBox(height: 14),
            Tarjeta(
              titulo: 'Forma de pago',
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final p in Config.formasDePagoVenta)
                  _chip(p, _pago == p, () => setState(() => _pago = p)),
              ]),
            ),
            const SizedBox(height: 14),
            Tarjeta(
              titulo: 'Canal de venta',
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in Config.canalesVenta)
                  _chip(c, _canal == c, () => setState(() => _canal = c)),
              ]),
            ),
            const SizedBox(height: 14),
            Tarjeta(
              titulo: 'Datos (opcional)',
              child: Column(children: [
                TextField(
                  controller: _cliente,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Cliente'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nota,
                  decoration: const InputDecoration(labelText: 'Nota'),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Text('TOTAL', style: Marca.etiqueta(size: 13)),
              const Spacer(),
              Text(formatearPrecio(_total),
                  style: Marca.titulo(38,
                      color: Marca.champagne, peso: FontWeight.w600)),
            ]),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _guardando || _items.isEmpty ? null : _confirmar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text('CONFIRMAR VENTA'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String t, bool sel, VoidCallback f) => ChoiceChip(
        label: Text(t, style: TextStyle(color: sel ? Marca.negro : Marca.marfil)),
        selected: sel,
        onSelected: (_) => f(),
      );
}

/// Lista con buscador para elegir qué prenda se vendió.
class _BuscadorPrendas extends StatefulWidget {
  const _BuscadorPrendas({required this.prendas});
  final List<Prenda> prendas;

  @override
  State<_BuscadorPrendas> createState() => _BuscadorPrendasState();
}

class _BuscadorPrendasState extends State<_BuscadorPrendas> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final lista = widget.prendas
        .where((p) =>
            q.isEmpty ||
            p.nombre.toLowerCase().contains(q) ||
            p.categoria.toLowerCase().contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .8,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'Buscar prenda…', prefixIcon: Icon(Icons.search)),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? const SinDatos('No hay prendas con ese nombre')
              : ListView.builder(
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final p = lista[i];
                    return ListTile(
                      onTap: p.agotada ? null : () => Navigator.pop(context, p),
                      leading: SizedBox(
                        width: 44,
                        height: 44,
                        child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: FotoPrenda(url: p.imagenUrl)),
                      ),
                      title: Text(p.nombre),
                      subtitle: Text(
                        '${p.precioFinalTexto}${p.enOferta ? ' (oferta)' : ''} · ${p.controlaStock ? (p.agotada ? 'SIN STOCK' : 'Stock: ${p.stockTotal}') : 'Sin control de stock'}',
                        style: TextStyle(
                            color: p.agotada
                                ? Theme.of(context).colorScheme.error
                                : Marca.gris),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

/// Elegir talle, cantidad y precio final de una prenda vendida.
class _DetalleItem extends StatefulWidget {
  const _DetalleItem({required this.prenda, required this.yaEnTicket});
  final Prenda prenda;
  final int Function(String talle) yaEnTicket;

  @override
  State<_DetalleItem> createState() => _DetalleItemState();
}

class _DetalleItemState extends State<_DetalleItem> {
  String? _talle;
  int _cantidad = 1;
  late final _precio =
      TextEditingController(text: _numTexto(widget.prenda.precioFinal));

  static String _numTexto(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  void initState() {
    super.initState();
    final claves = widget.prenda.clavesStock;
    if (claves.length == 1) _talle = claves.first;
  }

  @override
  void dispose() {
    _precio.dispose();
    super.dispose();
  }

  /// Unidades que todavía se pueden vender de esa variante (null = sin límite).
  int? _disponible(String clave) {
    final s = widget.prenda.stockClave(clave);
    return s == null ? null : s - widget.yaEnTicket(clave);
  }

  double? _leerPrecio(String t) {
    var x = t.trim().replaceAll('\$', '').replaceAll(' ', '');
    if (x.contains(',')) {
      x = x.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(x)) {
      x = x.replaceAll('.', '');
    }
    return double.tryParse(x);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prenda;
    final max = _talle == null ? null : _disponible(_talle!);
    final precio = _leerPrecio(_precio.text);
    final puede = _talle != null &&
        precio != null &&
        (max == null || (_cantidad <= max && max > 0));

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.nombre, style: Marca.titulo(28)),
          Text(
              p.enOferta
                  ? 'Lista: ${p.precioTexto} · En oferta "${p.ofertaNombre}": ${p.precioFinalTexto}'
                  : 'Precio de lista: ${p.precioTexto}',
              style: const TextStyle(color: Marca.gris)),
          if (p.clavesStock.length > 1) ...[
            const SizedBox(height: 18),
            Text(p.colores.isEmpty ? 'TALLE' : 'TALLE Y COLOR',
                style: Marca.etiqueta()),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in p.clavesStock)
                Builder(builder: (context) {
                  final d = _disponible(t);
                  final sinStock = d != null && d <= 0;
                  final sel = _talle == t;
                  final (_, color) = partesVariante(t);
                  return ChoiceChip(
                    avatar: color == null ? null : PuntoColor(color),
                    label: Text(
                      d == null
                          ? etiquetaVariante(t)
                          : '${etiquetaVariante(t)}  ($d)',
                      style: TextStyle(
                        color: sel ? Marca.negro : Marca.marfil,
                        decoration:
                            sinStock ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    selected: sel,
                    onSelected: sinStock
                        ? null
                        : (_) => setState(() {
                              _talle = t;
                              _cantidad = 1;
                            }),
                  );
                }),
            ]),
          ],
          const SizedBox(height: 18),
          Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('CANTIDAD', style: Marca.etiqueta()),
              const SizedBox(height: 8),
              SelectorCantidad(
                valor: _cantidad,
                onMenos: () => setState(
                    () => _cantidad = _cantidad > 1 ? _cantidad - 1 : 1),
                onMas: () => setState(() {
                  if (max == null || _cantidad < max) _cantidad++;
                }),
              ),
            ]),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _precio,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Precio de venta c/u', prefixText: '\$ '),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
          if (max != null) ...[
            const SizedBox(height: 8),
            Text(
              max > 0 ? 'Disponibles: $max' : 'No queda stock de este talle',
              style: TextStyle(
                  color: max > 0
                      ? Marca.gris
                      : Theme.of(context).colorScheme.error,
                  fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: !puede
                  ? null
                  : () => Navigator.pop(
                        context,
                        ItemVenta(
                          prendaId: p.id,
                          nombre: p.nombre,
                          categoria: p.categoria,
                          talle: _talle!,
                          cantidad: _cantidad,
                          precioUnitario: precio!,
                        ),
                      ),
              child: Text(precio == null
                  ? 'AGREGAR'
                  : 'AGREGAR · ${formatearPrecio(precio * _cantidad)}'),
            ),
          ),
        ],
      ),
    );
  }
}
