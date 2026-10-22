import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'carrito.dart' show confirmar;
import 'catalogo.dart' show FotoPrenda;
import 'config.dart';
import 'oferta.dart';
import 'prenda.dart';
import 'servicio.dart';
import 'tema.dart';
import 'venta.dart' show fechaCompleta, horaMinutos;

const _verde = Color(0xFF7BC47F);
const _ambar = Color(0xFFE0B354);

Color _colorEstado(String e) => switch (e) {
      'Activa' => _verde,
      'Programada' => _ambar,
      _ => Marca.gris,
    };

String _fechaHora(DateTime d) => '${fechaCompleta(d)} ${horaMinutos(d)}';

// =====================================================================
// Pestaña Ofertas
// =====================================================================

class OfertasTab extends StatefulWidget {
  const OfertasTab({super.key});

  @override
  State<OfertasTab> createState() => OfertasTabState();
}

class OfertasTabState extends State<OfertasTab> {
  List<Oferta> _ofertas = [];
  List<Prenda> _prendas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    recargar();
  }

  Future<void> recargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      _prendas = await Servicio.listarPrendas();
      _ofertas = await Servicio.listarOfertas();
    } catch (e) {
      _error = mensajeError(e);
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> editar([Oferta? o]) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => FormularioOferta(oferta: o, prendas: _prendas)),
    );
    if (ok == true) recargar();
  }

  Future<void> _activar(Oferta o, bool v) async {
    try {
      await Servicio.activarOferta(o.id!, v);
      recargar();
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  Future<void> _borrar(Oferta o) async {
    if (!await confirmar(context, 'Borrar oferta',
        '¿Borrar "${o.nombre}"? Las prendas vuelven a su precio de lista.')) {
      return;
    }
    try {
      await Servicio.borrarOferta(o.id!);
      recargar();
    } catch (e) {
      if (mounted) avisar(context, mensajeError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final porId = {for (final p in _prendas) p.id: p};
    return RefreshIndicator(
      onRefresh: recargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          const Text(
            'Agrupá prendas en una oferta con un % de descuento o un precio '
            'especial. Puede tener fecha de fin o quedar abierta hasta que la pauses.',
            style: TextStyle(color: Marca.gris),
          ),
          const SizedBox(height: 16),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child: CircularProgressIndicator(color: Marca.champagne)),
            )
          else if (_error != null)
            Tarjeta(
              child: Column(children: [
                Text('No se pudieron cargar las ofertas:\n$_error',
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('¿Corriste supabase/03_ofertas_publico.sql?',
                    style: TextStyle(color: Marca.gris)),
              ]),
            )
          else if (_ofertas.isEmpty)
            const SinDatos('Todavía no hay ofertas.\nTocá "Nueva oferta".')
          else
            for (final o in _ofertas)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => editar(o),
                  child: Tarjeta(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(o.nombre, style: Marca.titulo(28))),
                          Switch(
                              value: o.activa,
                              onChanged: (v) => _activar(o, v)),
                          PopupMenuButton<String>(
                            onSelected: (v) =>
                                v == 'editar' ? editar(o) : _borrar(o),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'editar', child: Text('Editar')),
                              PopupMenuItem(
                                  value: 'borrar', child: Text('Borrar')),
                            ],
                          ),
                        ]),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: _colorEstado(o.estado)),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(o.estado.toUpperCase(),
                                  style: Marca.etiqueta(
                                      size: 10,
                                      color: _colorEstado(o.estado))),
                            ),
                            if (o.descuento > 0)
                              Text('-${o.descuento.round()}%',
                                  style: const TextStyle(
                                      color: Marca.champagne,
                                      fontWeight: FontWeight.w700)),
                            Text('${o.prendas.length} prendas',
                                style: const TextStyle(color: Marca.gris)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            if (o.desde != null) 'Desde ${_fechaHora(o.desde!)}',
                            o.hasta != null
                                ? 'Hasta ${_fechaHora(o.hasta!)}'
                                : 'Sin vencimiento',
                            if (o.vigente && textoVencimiento(o.hasta) != null)
                              textoVencimiento(o.hasta)!,
                          ].join(' · '),
                          style:
                              const TextStyle(color: Marca.gris, fontSize: 12),
                        ),
                        if (o.prendas.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 56,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (final id in o.prendas.keys.take(12))
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: SizedBox(
                                      width: 44,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(3),
                                        child: FotoPrenda(
                                            url: porId[id]?.imagenUrl),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// =====================================================================
// Crear / editar oferta
// =====================================================================

class FormularioOferta extends StatefulWidget {
  const FormularioOferta({super.key, this.oferta, required this.prendas});
  final Oferta? oferta;
  final List<Prenda> prendas;

  @override
  State<FormularioOferta> createState() => _FormularioOfertaState();
}

class _FormularioOfertaState extends State<FormularioOferta> {
  late final _nombre = TextEditingController(text: widget.oferta?.nombre);
  late final _descuento = TextEditingController(
      text: (widget.oferta?.descuento ?? 0) > 0
          ? widget.oferta!.descuento.round().toString()
          : '');
  late DateTime? _desde = widget.oferta?.desde;
  late DateTime? _hasta = widget.oferta?.hasta;
  late bool _conFecha = widget.oferta?.hasta != null;
  late bool _activa = widget.oferta?.activa ?? true;

  /// prendaId -> precio especial (null = usa el %)
  late final Map<String, double?> _sel = Map.of(widget.oferta?.prendas ?? {});
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _descuento.dispose();
    super.dispose();
  }

  double get _pct =>
      (double.tryParse(_descuento.text.replaceAll(',', '.').trim()) ?? 0)
          .clamp(0, 95)
          .toDouble();

  /// Oferta con lo que hay cargado en el formulario (para previsualizar precios).
  Oferta get _borrador => Oferta(
        id: widget.oferta?.id,
        nombre: _nombre.text.trim(),
        descuento: _pct,
        desde: _conFecha ? _desde : null,
        hasta: _conFecha ? _hasta : null,
        activa: _activa,
        prendas: _sel,
      );

  Future<DateTime?> _elegirFechaHora(DateTime? inicial, {bool fin = false}) async {
    final ahora = DateTime.now();
    final base = inicial ??
        (fin
            ? DateTime(ahora.year, ahora.month, ahora.day + 7, 23, 59)
            : ahora);
    final d = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(ahora.year - 1),
      lastDate: DateTime(ahora.year + 2),
    );
    if (d == null || !mounted) return null;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: base.hour, minute: base.minute),
    );
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _elegirPrendas() async {
    final r = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SelectorPrendas(
        prendas: widget.prendas,
        seleccionadas: _sel.keys.toSet(),
      ),
    );
    if (r == null) return;
    setState(() {
      _sel.removeWhere((k, _) => !r.contains(k));
      for (final id in r) {
        _sel.putIfAbsent(id, () => null);
      }
    });
  }

  Future<void> _precioEspecial(Prenda p) async {
    final ctrl = TextEditingController(
        text: _sel[p.id] == null ? '' : _sel[p.id]!.round().toString());
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(p.nombre),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Precio de lista: ${p.precioTexto}',
              style: const TextStyle(color: Marca.gris)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Precio especial', prefixText: '\$ '),
          ),
          const SizedBox(height: 6),
          const Text('Vacío = usa el % de la oferta',
              style: TextStyle(color: Marca.gris, fontSize: 12)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text('Aceptar')),
        ],
      ),
    );
    ctrl.dispose();
    if (r == null) return;
    final v = double.tryParse(
        r.replaceAll('.', '').replaceAll(',', '.').replaceAll('\$', '').trim());
    setState(() => _sel[p.id!] = (v != null && v > 0) ? v : null);
  }

  Future<void> _guardar() async {
    final o = _borrador;
    String? error;
    if (o.nombre.isEmpty) {
      error = 'Poné un nombre a la oferta';
    } else if (_sel.isEmpty) {
      error = 'Elegí al menos una prenda';
    } else if (o.descuento <= 0 && _sel.values.any((v) => v == null)) {
      error = 'Poné un % de descuento o un precio especial a cada prenda';
    } else if (_conFecha && _hasta == null) {
      error = 'Elegí hasta cuándo dura';
    } else if (_conFecha &&
        _desde != null &&
        _hasta != null &&
        !_hasta!.isAfter(_desde!)) {
      error = 'La fecha de fin tiene que ser posterior al inicio';
    }
    if (error != null) {
      avisar(context, error);
      return;
    }
    setState(() => _guardando = true);
    try {
      await Servicio.guardarOferta(o);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        avisar(context, 'No se pudo guardar: ${mensajeError(e)}');
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final borrador = _borrador;
    final elegidas = widget.prendas.where((p) => _sel.containsKey(p.id)).toList();

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.oferta == null ? 'Nueva oferta' : 'Editar oferta')),
      body: Centrado(
        maxAncho: 720,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Tarjeta(
              titulo: 'Oferta',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nombre,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        hintText: 'Ej: Hot Sale, Liquidación de invierno'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _descuento,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Descuento', suffixText: '% OFF'),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final n in [10, 15, 20, 25, 30, 40, 50])
                      ChoiceChip(
                        label: Text('$n%',
                            style: TextStyle(
                                color: _pct == n ? Marca.negro : Marca.marfil)),
                        selected: _pct == n,
                        onSelected: (_) =>
                            setState(() => _descuento.text = '$n'),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _activa,
                    onChanged: (v) => setState(() => _activa = v),
                    title: const Text('Activa'),
                    subtitle: const Text('Apagala para pausarla sin borrarla',
                        style: TextStyle(color: Marca.gris)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Tarjeta(
              titulo: 'Duración',
              accion: Switch(
                value: _conFecha,
                onChanged: (v) => setState(() {
                  _conFecha = v;
                  if (v && _hasta == null) {
                    final h = DateTime.now();
                    _hasta = DateTime(h.year, h.month, h.day + 7, 23, 59);
                  }
                }),
              ),
              child: !_conFecha
                  ? const Text(
                      'Sin vencimiento: dura hasta que la pauses o la borres.',
                      style: TextStyle(color: Marca.gris))
                  : Column(children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.play_arrow_outlined),
                        title: const Text('Empieza'),
                        subtitle: Text(_desde == null
                            ? 'Ya mismo'
                            : _fechaHora(_desde!)),
                        trailing: _desde == null
                            ? null
                            : IconButton(
                                tooltip: 'Empezar ya',
                                onPressed: () => setState(() => _desde = null),
                                icon: const Icon(Icons.close, size: 18)),
                        onTap: () async {
                          final d = await _elegirFechaHora(_desde);
                          if (d != null) setState(() => _desde = d);
                        },
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.flag_outlined),
                        title: const Text('Termina'),
                        subtitle: Text(
                            _hasta == null ? 'Elegir' : _fechaHora(_hasta!)),
                        onTap: () async {
                          final d = await _elegirFechaHora(_hasta, fin: true);
                          if (d != null) setState(() => _hasta = d);
                        },
                      ),
                    ]),
            ),
            const SizedBox(height: 14),
            Tarjeta(
              titulo: 'Prendas (${_sel.length})',
              accion: TextButton.icon(
                onPressed: _elegirPrendas,
                icon: const Icon(Icons.checklist, size: 18),
                label: const Text('Elegir'),
              ),
              child: elegidas.isEmpty
                  ? InkWell(
                      onTap: _elegirPrendas,
                      child: const SinDatos(
                          'Tocá "Elegir" para sumar prendas a la oferta'),
                    )
                  : Column(children: [
                      for (final p in elegidas)
                        Builder(builder: (context) {
                          final nuevo = borrador.precioPara(p);
                          final especial = _sel[p.id] != null;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: SizedBox(
                              width: 40,
                              height: 50,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: FotoPrenda(url: p.imagenUrl),
                              ),
                            ),
                            title: Text(p.nombre,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text.rich(TextSpan(children: [
                              TextSpan(
                                  text: p.precioTexto,
                                  style: const TextStyle(
                                      color: Marca.gris,
                                      decoration: TextDecoration.lineThrough)),
                              const TextSpan(text: '  →  '),
                              TextSpan(
                                text: nuevo == null
                                    ? 'sin descuento'
                                    : formatearPrecio(nuevo),
                                style: TextStyle(
                                    color: nuevo == null
                                        ? Theme.of(context).colorScheme.error
                                        : Marca.champagne,
                                    fontWeight: FontWeight.w600),
                              ),
                              if (especial)
                                const TextSpan(
                                    text: '  (precio especial)',
                                    style: TextStyle(
                                        color: Marca.gris, fontSize: 11)),
                            ])),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Precio especial',
                                  onPressed: () => _precioEspecial(p),
                                  icon: const Icon(Icons.edit_outlined,
                                      size: 18),
                                ),
                                IconButton(
                                  tooltip: 'Quitar',
                                  onPressed: () =>
                                      setState(() => _sel.remove(p.id)),
                                  icon: const Icon(Icons.close,
                                      size: 18, color: Marca.gris),
                                ),
                              ],
                            ),
                          );
                        }),
                    ]),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check),
              label: const Text('GUARDAR OFERTA'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista con casillas para elegir prendas, con atajos por categoría y público.
class _SelectorPrendas extends StatefulWidget {
  const _SelectorPrendas({required this.prendas, required this.seleccionadas});
  final List<Prenda> prendas;
  final Set<String> seleccionadas;

  @override
  State<_SelectorPrendas> createState() => _SelectorPrendasState();
}

class _SelectorPrendasState extends State<_SelectorPrendas> {
  late final Set<String> _sel = {...widget.seleccionadas};
  String _q = '';

  void _alternarGrupo(Iterable<Prenda> grupo) {
    final ids = grupo.map((p) => p.id!).toSet();
    setState(() {
      if (ids.every(_sel.contains)) {
        _sel.removeAll(ids);
      } else {
        _sel.addAll(ids);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final todas = widget.prendas.where((p) => p.id != null).toList();
    final q = _q.toLowerCase();
    final lista = todas
        .where((p) =>
            q.isEmpty ||
            p.nombre.toLowerCase().contains(q) ||
            p.categoria.toLowerCase().contains(q))
        .toList();
    final categorias = todas
        .map((p) => p.categoria.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final publicos =
        Config.publicos.where((pub) => todas.any((p) => p.publico == pub));

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .85,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            decoration: const InputDecoration(
                hintText: 'Buscar…',
                prefixIcon: Icon(Icons.search),
                isDense: true),
            onChanged: (v) => setState(() => _q = v),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _atajo('Todas', todas),
              for (final pub in publicos)
                _atajo(pub, todas.where((p) => p.publico == pub)),
              for (final c in categorias)
                _atajo(c, todas.where((p) => p.categoria.trim() == c)),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: ListView.builder(
            itemCount: lista.length,
            itemBuilder: (context, i) {
              final p = lista[i];
              return CheckboxListTile(
                value: _sel.contains(p.id),
                onChanged: (v) => setState(
                    () => v == true ? _sel.add(p.id!) : _sel.remove(p.id)),
                secondary: SizedBox(
                  width: 40,
                  height: 50,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: FotoPrenda(url: p.imagenUrl),
                  ),
                ),
                title: Text(p.nombre),
                subtitle: Text(
                    [p.precioTexto, p.categoria, p.publico]
                        .where((t) => t.isNotEmpty)
                        .join(' · '),
                    style: const TextStyle(color: Marca.gris, fontSize: 12)),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _sel),
                child: Text('LISTO (${_sel.length})'),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _atajo(String texto, Iterable<Prenda> grupo) {
    final ids = grupo.map((p) => p.id).toSet();
    final todos = ids.isNotEmpty && ids.every(_sel.contains);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(texto,
            style: TextStyle(color: todos ? Marca.negro : Marca.marfil)),
        selected: todos,
        showCheckmark: false,
        onSelected: (_) => _alternarGrupo(grupo),
      ),
    );
  }
}
