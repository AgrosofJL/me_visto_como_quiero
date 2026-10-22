import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin_ui.dart';
import 'carrito.dart' show confirmar;
import 'catalogo.dart';
import 'colores.dart';
import 'config.dart';
import 'prenda.dart';
import 'rubro.dart';
import 'rubros_admin.dart';
import 'servicio.dart';
import 'ofertas_admin.dart';
import 'tablero.dart';
import 'tema.dart';
import 'ventas_admin.dart';

/// Entrada al panel: muestra el login o la lista de prendas para editar.
class AdministradorPage extends StatefulWidget {
  const AdministradorPage({super.key});

  @override
  State<AdministradorPage> createState() => _AdministradorPageState();
}

class _AdministradorPageState extends State<AdministradorPage> {
  bool? _esAdmin; // null = verificando

  @override
  void initState() {
    super.initState();
    _verificar();
  }

  Future<void> _verificar() async {
    setState(() => _esAdmin = null);
    bool ok = false;
    try {
      ok = await Servicio.esAdmin();
    } catch (_) {
      // Sin conexión o sin sesión: se trata como no admin.
    }
    if (mounted) setState(() => _esAdmin = ok);
  }

  @override
  Widget build(BuildContext context) {
    if (_esAdmin == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!Servicio.haySesion) return _Login(onEntrar: _verificar);
    if (_esAdmin == false) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administrar')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'El usuario ${Servicio.emailActual} no tiene permiso de '
                  'administrador.\nAgregalo a la tabla "admins" en Supabase.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () async {
                    await Servicio.salir();
                    _verificar();
                  },
                  child: const Text('Salir'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return _PanelAdmin(
      onSalir: () async {
        await Servicio.salir();
        _verificar();
      },
    );
  }
}

// ------------------------------------------------------------------
// Login
// ------------------------------------------------------------------

class _Login extends StatefulWidget {
  const _Login({required this.onEntrar});
  final VoidCallback onEntrar;

  @override
  State<_Login> createState() => _LoginState();
}

class _LoginState extends State<_Login> {
  final _email = TextEditingController();
  final _clave = TextEditingController();
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await Servicio.entrar(_email.text, _clave.text);
      widget.onEntrar();
    } on AuthException catch (e) {
      setState(() => _error = e.message == 'Invalid login credentials'
          ? 'Email o contraseña incorrectos'
          : e.message);
    } catch (e) {
      setState(() => _error = 'Error: $e');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingreso administrador')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.storefront, size: 56),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clave,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    onSubmitted: (_) => _entrar(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _enviando ? null : _entrar,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _enviando
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Entrar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Panel de gestión: Tablero · Ventas · Prendas
// ------------------------------------------------------------------

class _PanelAdmin extends StatefulWidget {
  const _PanelAdmin({required this.onSalir});
  final VoidCallback onSalir;

  @override
  State<_PanelAdmin> createState() => _PanelAdminState();
}

class _PanelAdminState extends State<_PanelAdmin> {
  int _tab = 0;
  final _tablero = GlobalKey<TableroTabState>();
  final _ventas = GlobalKey<VentasTabState>();
  final _prendas = GlobalKey<_PrendasTabState>();
  final _ofertas = GlobalKey<OfertasTabState>();

  static const _titulos = ['Tablero', 'Ventas', 'Stock y prendas', 'Ofertas'];

  void _refrescarTodo() {
    _tablero.currentState?.recargar();
    _ventas.currentState?.recargar();
    _prendas.currentState?.recargar();
    _ofertas.currentState?.recargar();
  }

  Future<void> _nuevaVenta() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const NuevaVentaPage()),
    );
    if (ok == true) _refrescarTodo();
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final rail = ancho >= 900;

    final cuerpo = IndexedStack(
      index: _tab,
      children: [
        TableroTab(key: _tablero),
        VentasTab(key: _ventas),
        _PrendasTab(key: _prendas, onCambio: _refrescarTodo),
        OfertasTab(key: _ofertas),
      ],
    );

    const destinos = [
      (Icons.dashboard_outlined, Icons.dashboard, 'Tablero'),
      (Icons.receipt_long_outlined, Icons.receipt_long, 'Ventas'),
      (Icons.inventory_2_outlined, Icons.inventory_2, 'Stock'),
      (Icons.local_offer_outlined, Icons.local_offer, 'Ofertas'),
    ];

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(_titulos[_tab]),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refrescarTodo,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Ver tienda',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.storefront_outlined),
          ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: widget.onSalir,
          ),
        ],
      ),
      floatingActionButton: _tab == 2
          ? FloatingActionButton.extended(
              onPressed: () => _prendas.currentState?.editar(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva prenda'),
            )
          : _tab == 3
          ? FloatingActionButton.extended(
              onPressed: () => _ofertas.currentState?.editar(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva oferta'),
            )
          : FloatingActionButton.extended(
              onPressed: _nuevaVenta,
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Nueva venta'),
            ),
      bottomNavigationBar: rail
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                for (final d in destinos)
                  NavigationDestination(
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2),
                      label: d.$3),
              ],
            ),
      body: rail
          ? Row(children: [
              NavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                labelType: NavigationRailLabelType.all,
                backgroundColor: Marca.superficie,
                destinations: [
                  for (final d in destinos)
                    NavigationRailDestination(
                        icon: Icon(d.$1),
                        selectedIcon: Icon(d.$2),
                        label: Text(d.$3)),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: Centrado(maxAncho: 1300, child: cuerpo)),
            ])
          : cuerpo,
    );
  }
}

// ------------------------------------------------------------------
// Pestaña Stock y prendas
// ------------------------------------------------------------------

class _PrendasTab extends StatefulWidget {
  const _PrendasTab({super.key, required this.onCambio});
  final VoidCallback onCambio;

  @override
  State<_PrendasTab> createState() => _PrendasTabState();
}

class _PrendasTabState extends State<_PrendasTab> {
  List<Prenda> _prendas = [];
  Map<String, double> _costos = {};
  List<Rubro> _rubros = [];
  String? _rubroFiltro; // null = todos
  bool _cargando = true;
  String _q = '';
  String _filtro = 'Todas';

  @override
  void initState() {
    super.initState();
    recargar();
  }

  Future<void> recargar() async {
    setState(() => _cargando = true);
    try {
      _prendas = await Servicio.catalogo();
    } catch (e) {
      if (mounted) avisar(context, 'No se pudo cargar: ${mensajeError(e)}');
    }
    try {
      _costos = await Servicio.listarCostos();
    } catch (_) {
      _costos = {}; // Todavía no se corrió 02_stock_ventas.sql
    }
    try {
      _rubros = await Servicio.listarRubros();
    } catch (_) {
      _rubros = []; // Todavía no se corrió 04_rubros.sql
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> editar([Prenda? p]) async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioPrenda(
          prenda: p,
          costo: p?.id == null ? null : _costos[p!.id],
          rubros: _rubros,
          rubroInicial: _rubroFiltro,
        ),
      ),
    );
    if (guardado == true) {
      recargar();
      widget.onCambio();
    }
  }

  Future<void> _vender(Prenda p) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => NuevaVentaPage(prendaInicial: p)),
    );
    if (ok == true) widget.onCambio();
  }

  Future<void> _borrar(Prenda p) async {
    final ok = await confirmar(context, 'Borrar prenda',
        '¿Seguro que querés borrar "${p.nombre}"? Las ventas ya registradas se conservan.');
    if (!ok) return;
    try {
      await Servicio.borrarPrenda(p);
      if (mounted) avisar(context, 'Prenda borrada');
      recargar();
      widget.onCambio();
    } catch (e) {
      if (mounted) avisar(context, 'No se pudo borrar: ${mensajeError(e)}');
    }
  }

  Future<void> _abrirRubros() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RubrosPage()),
    );
    recargar();
  }

  bool _tieneBajo(Prenda p) =>
      p.controlaStock &&
      p.clavesStock.any((t) {
        final n = p.stock[t] ?? 0;
        return n > 0 && n <= Config.stockBajo;
      });

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final lista = _prendas.where((p) {
      final okQ = q.isEmpty ||
          p.nombre.toLowerCase().contains(q) ||
          p.categoria.toLowerCase().contains(q);
      final okF = switch (_filtro) {
        'Sin stock' => p.agotada ||
            (p.controlaStock && p.clavesStock.any((t) => (p.stock[t] ?? 0) <= 0)),
        'Stock bajo' => _tieneBajo(p),
        'Ocultas' => !p.disponible,
        _ => true,
      };
      final okR = _rubroFiltro == null || p.rubroId == _rubroFiltro;
      return okQ && okF && okR;
    }).toList();

    final totalUnidades = _prendas
        .where((p) => p.controlaStock)
        .fold<int>(0, (s, p) => s + p.stockTotal);

    return RefreshIndicator(
      onRefresh: recargar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar prenda o categoría…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _q = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in ['Todas', 'Sin stock', 'Stock bajo', 'Ocultas'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f,
                          style: TextStyle(
                              color: _filtro == f
                                  ? Marca.negro
                                  : Marca.marfil)),
                      selected: _filtro == f,
                      onSelected: (_) => setState(() => _filtro = f),
                    ),
                  ),
              ],
            ),
          ),
          if (_rubros.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final r in [null, ..._rubros])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                            r == null
                                ? 'Todos los rubros'
                                : '${r.nombre} (${_prendas.where((p) => p.rubroId == r.id).length})',
                            style: TextStyle(
                                color: _rubroFiltro == r?.id
                                    ? Marca.negro
                                    : Marca.marfil)),
                        selected: _rubroFiltro == r?.id,
                        onSelected: (_) =>
                            setState(() => _rubroFiltro = r?.id),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: Text(
                  '${_prendas.length} prendas · $totalUnidades unidades en stock',
                  style: const TextStyle(color: Marca.gris, fontSize: 12)),
            ),
            TextButton.icon(
              onPressed: _abrirRubros,
              icon: const Icon(Icons.category_outlined, size: 18),
              label: const Text('Rubros'),
            ),
          ]),
          const SizedBox(height: 4),
          const SizedBox(height: 10),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child: CircularProgressIndicator(color: Marca.champagne)),
            )
          else if (lista.isEmpty)
            const SinDatos('No hay prendas para mostrar')
          else
            Tarjeta(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final p in lista) ...[
                  _FilaPrenda(
                    prenda: p,
                    costo: _costos[p.id],
                    rubro: _rubros
                        .where((r) => r.id == p.rubroId)
                        .map((r) => r.nombre)
                        .firstOrNull,
                    onTap: () => editar(p),
                    onVender: () => _vender(p),
                    onBorrar: () => _borrar(p),
                  ),
                  if (p != lista.last) const Divider(),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}

class _FilaPrenda extends StatelessWidget {
  const _FilaPrenda({
    required this.prenda,
    required this.costo,
    this.rubro,
    required this.onTap,
    required this.onVender,
    required this.onBorrar,
  });
  final Prenda prenda;
  final double? costo;
  final String? rubro;
  final VoidCallback onTap;
  final VoidCallback onVender;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    final p = prenda;
    final error = Theme.of(context).colorScheme.error;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              height: 70,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: FotoPrenda(url: p.imagenUrl),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(p.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ),
                    if (!p.disponible) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.visibility_off,
                          size: 14, color: Marca.gris),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    [
                      p.enOferta
                          ? '${p.precioFinalTexto} (oferta, lista ${p.precioTexto})'
                          : p.precioTexto,
                      if (costo != null && costo! > 0)
                        'costo ${formatearPrecio(costo!)}',
                      if (p.categoria.isNotEmpty) p.categoria,
                      if (rubro != null) rubro!,
                      if (p.publico.isNotEmpty) p.publico,
                    ].join(' · '),
                    style: const TextStyle(color: Marca.gris, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  if (!p.controlaStock)
                    const Text('Sin control de stock',
                        style: TextStyle(color: Marca.gris, fontSize: 11))
                  else
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      for (final t in p.clavesStock)
                        Builder(builder: (context) {
                          final n = p.stock[t] ?? 0;
                          final color = n <= 0
                              ? error
                              : n <= Config.stockBajo
                                  ? const Color(0xFFE0B354)
                                  : Marca.marfil;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: color.withValues(alpha: .6)),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              t == talleUnico ? '$n u.' : '${etiquetaVariante(t)}: $n',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          );
                        }),
                    ]),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Registrar venta',
              onPressed: p.agotada ? null : onVender,
              icon: const Icon(Icons.point_of_sale, color: Marca.champagne),
            ),
            PopupMenuButton<String>(
              onSelected: (v) => v == 'editar' ? onTap() : onBorrar(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'editar', child: Text('Editar / stock')),
                PopupMenuItem(value: 'borrar', child: Text('Borrar')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Formulario para crear / editar una prenda
// ------------------------------------------------------------------

class FormularioPrenda extends StatefulWidget {
  const FormularioPrenda({
    super.key,
    this.prenda,
    this.costo,
    this.rubros = const [],
    this.rubroInicial,
  });

  /// Rubros disponibles para elegir.
  final List<Rubro> rubros;

  /// Rubro preseleccionado para prendas nuevas.
  final String? rubroInicial;
  final Prenda? prenda;

  /// Costo de compra actual (solo lo ve el admin).
  final double? costo;

  @override
  State<FormularioPrenda> createState() => _FormularioPrendaState();
}

class _FormularioPrendaState extends State<FormularioPrenda> {
  final _form = GlobalKey<FormState>();
  late final _nombre = TextEditingController(text: widget.prenda?.nombre);
  late final _descripcion =
      TextEditingController(text: widget.prenda?.descripcion);
  late final _precio = TextEditingController(
      text: widget.prenda == null ? '' : _numATexto(widget.prenda!.precio));
  late final _categoria =
      TextEditingController(text: widget.prenda?.categoria);
  /// Talles de la prenda, en orden (vacío = talle único).
  late final List<String> _listaTalles = [
    for (final t in widget.prenda?.talles ?? const <String>[])
      ...separarTalles(t),
  ];
  final _nuevoTalle = TextEditingController();

  /// Colores de la prenda (vacío = un solo color / no aplica).
  late final List<String> _listaColores = List.of(widget.prenda?.colores ?? []);
  final _nuevoColor = TextEditingController();
  late bool _disponible = widget.prenda?.disponible ?? true;
  late final _costo = TextEditingController(
      text: widget.costo == null ? '' : _numATexto(widget.costo!));
  late bool _controlaStock = widget.prenda?.controlaStock ?? true;
  late String _publico = widget.prenda?.publico ?? '';
  late String? _rubroId = widget.prenda != null
      ? widget.prenda!.rubroId
      : (widget.rubroInicial ??
          (widget.rubros.isEmpty ? null : widget.rubros.first.id));
  final Map<String, TextEditingController> _stockCtrl = {};

  List<String> get _tallesOUnico =>
      _listaTalles.isEmpty ? const [talleUnico] : _listaTalles;

  /// Combinaciones talle/color con su clave de stock.
  List<String> get _clavesStock => [
        for (final t in _tallesOUnico)
          if (_listaColores.isEmpty)
            Prenda.clave(t, null)
          else
            for (final c in _listaColores) Prenda.clave(t, c),
      ];

  void _agregarColores(Iterable<String> colores) {
    setState(() {
      for (final c in colores.map(capitalizarColor)) {
        if (c.isNotEmpty &&
            !_listaColores.any((x) => x.toLowerCase() == c.toLowerCase())) {
          _listaColores.add(c);
        }
      }
    });
  }

  void _agregarColorEscrito() {
    _agregarColores(_nuevoColor.text.split(RegExp(r'[,;/]+')));
    _nuevoColor.clear();
  }

  /// Suma de un talle en todos sus colores.
  int _totalTalle(String t) => _listaColores.isEmpty
      ? _cantidad(Prenda.clave(t, null))
      : _listaColores.fold<int>(
          0, (s, c) => s + _cantidad(Prenda.clave(t, c)));

  int _cantidad(String talle) =>
      int.tryParse(_ctrlStock(talle).text.trim()) ?? 0;

  void _sumar(String talle, int delta) {
    final n = (_cantidad(talle) + delta).clamp(0, 99999);
    setState(() => _ctrlStock(talle).text = '$n');
  }

  void _agregarTalles(Iterable<String> talles) {
    setState(() {
      for (final t in talles.map((t) => t.trim().toUpperCase())) {
        if (t.isNotEmpty && t != talleUnico.toUpperCase() &&
            !_listaTalles.contains(t)) {
          _listaTalles.add(t);
        }
      }
    });
  }

  void _agregarTalleEscrito() {
    _agregarTalles(separarTalles(_nuevoTalle.text));
    _nuevoTalle.clear();
  }

  TextEditingController _ctrlStock(String talle) => _stockCtrl.putIfAbsent(
      talle,
      () => TextEditingController(
          text: '${widget.prenda?.stock[talle] ?? 0}'));

  int get _stockTotalForm =>
      _clavesStock.fold<int>(0, (s, t) => s + _cantidad(t));

  XFile? _fotoNueva;
  Uint8List? _fotoBytes;
  bool _guardando = false;

  static String _numATexto(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_nombre, _descripcion, _precio, _categoria, _nuevoTalle, _nuevoColor, _costo]) {
      c.dispose();
    }
    for (final c in _stockCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _elegirFoto(ImageSource origen) async {
    final archivo = await ImagePicker().pickImage(
      source: origen,
      maxWidth: 1400,
      imageQuality: 82,
    );
    if (archivo == null) return;
    final bytes = await archivo.readAsBytes();
    setState(() {
      _fotoNueva = archivo;
      _fotoBytes = bytes;
    });
  }

  /// Acepta "12500", "12.500" o "12.500,50".
  double? _leerPrecio(String texto) {
    var t = texto.trim().replaceAll('\$', '').replaceAll(' ', '');
    if (t.contains(',')) {
      t = t.replaceAll('.', '').replaceAll(',', '.');
    } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(t)) {
      t = t.replaceAll('.', '');
    }
    return double.tryParse(t);
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      String? url = widget.prenda?.imagenUrl;
      String? ruta = widget.prenda?.imagenPath;
      final rutaVieja = ruta;

      if (_fotoNueva != null && _fotoBytes != null) {
        final subida = await Servicio.subirFoto(
            _fotoBytes!, _fotoNueva!.name, _fotoNueva!.mimeType);
        url = subida.$1;
        ruta = subida.$2;
      }

      final prenda = Prenda(
        id: widget.prenda?.id,
        nombre: _nombre.text.trim(),
        descripcion: _descripcion.text.trim(),
        precio: _leerPrecio(_precio.text) ?? 0,
        categoria: _categoria.text.trim(),
        talles: List.of(_listaTalles),
        colores: List.of(_listaColores),
        imagenUrl: url,
        imagenPath: ruta,
        disponible: _disponible,
        publico: _publico,
        rubroId: _rubroId,
        stock: _controlaStock
            ? {
                for (final t in _clavesStock) t: _cantidad(t).clamp(0, 99999),
              }
            : const {},
      );
      final id = await Servicio.guardarPrenda(prenda);

      final costo = _leerPrecio(_costo.text);
      if (costo != null && costo != widget.costo) {
        await Servicio.guardarCosto(id, costo);
      }

      // Si se cambió la foto, borra la anterior para no ocupar espacio.
      if (rutaVieja != null && rutaVieja != ruta) {
        await Servicio.borrarFoto(rutaVieja);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: ${mensajeError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String? _textoMargen() {
    final precio = _leerPrecio(_precio.text);
    final costo = _leerPrecio(_costo.text);
    if (precio == null || costo == null || costo <= 0 || precio <= 0) {
      return null;
    }
    final g = precio - costo;
    return 'Ganancia por unidad: ${formatearPrecio(g)} (${(g / precio * 100).round()}%)';
  }

  static const _presetsTalles = {
    'Letras': ['XS', 'S', 'M', 'L', 'XL', 'XXL'],
    'Números': ['36', '38', '40', '42', '44', '46'],
    'Jean': ['26', '28', '30', '32', '34', '36', '38', '40'],
    'Niños': ['2', '4', '6', '8', '10', '12', '14', '16'],
    'Calzado': ['35', '36', '37', '38', '39', '40', '41', '42', '43', '44'],
    'Corpiño': ['85', '90', '95', '100', '105'],
  };

  Widget _filaCantidad(String clave, {required Widget etiqueta}) {
    final error = Theme.of(context).colorScheme.error;
    final n = _cantidad(clave);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Expanded(child: etiqueta),
        if (_controlaStock)
          SizedBox(
            width: 140,
            child: Row(children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _sumar(clave, -1),
                icon: const Icon(Icons.remove, size: 18),
              ),
              Expanded(
                child: TextField(
                  controller: _ctrlStock(clave),
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: n == 0
                        ? error
                        : n <= Config.stockBajo
                            ? const Color(0xFFE0B354)
                            : Marca.marfil,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _sumar(clave, 1),
                icon: const Icon(Icons.add, size: 18),
              ),
            ]),
          ),
      ]),
    );
  }

  Widget _seccionStock() {
    final conColores = _listaColores.isNotEmpty;
    return Tarjeta(
      titulo: 'Talles, colores y cantidades',
      accion: Row(mainAxisSize: MainAxisSize.min, children: [
        const Text('Controlar stock',
            style: TextStyle(color: Marca.gris, fontSize: 12)),
        Switch(
          value: _controlaStock,
          onChanged: (v) => setState(() => _controlaStock = v),
        ),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---------------- 1. Talles ----------------
          Text('1 · TALLES', style: Marca.etiqueta(color: Marca.champagne)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in _presetsTalles.entries)
              ActionChip(
                label: Text(e.key),
                tooltip: e.value.join(' · '),
                onPressed: () => _agregarTalles(e.value),
              ),
            ActionChip(
              avatar: const Icon(Icons.looks_one_outlined, size: 16),
              label: const Text('Talle único'),
              onPressed: () => setState(_listaTalles.clear),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _nuevoTalle,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Otro talle (ej: XL, 3XL, 48)',
                  isDense: true,
                ),
                onSubmitted: (_) => _agregarTalleEscrito(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              onPressed: _agregarTalleEscrito,
              child: const Text('AGREGAR'),
            ),
          ]),
          if (_listaTalles.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final t in _listaTalles)
                InputChip(
                  label: Text(t),
                  onDeleted: () => setState(() => _listaTalles.remove(t)),
                ),
            ]),
          ],
          const SizedBox(height: 20),

          // ---------------- 2. Colores ----------------
          Text('2 · COLORES (opcional)',
              style: Marca.etiqueta(color: Marca.champagne)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final c in coloresRapidos)
              if (!_listaColores.contains(c))
                ActionChip(
                  avatar: PuntoColor(c),
                  label: Text(c),
                  onPressed: () => _agregarColores([c]),
                ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _nuevoColor,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Otro color (ej: Azul marino, Estampado)',
                  isDense: true,
                ),
                onSubmitted: (_) => _agregarColorEscrito(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
              onPressed: _agregarColorEscrito,
              child: const Text('AGREGAR'),
            ),
          ]),
          if (conColores) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in _listaColores)
                InputChip(
                  avatar: PuntoColor(c),
                  label: Text(c),
                  onDeleted: () => setState(() => _listaColores.remove(c)),
                ),
            ]),
          ],
          const SizedBox(height: 20),

          // ---------------- 3. Cantidades ----------------
          Text(
              _controlaStock
                  ? '3 · CANTIDAD DE CADA UNO'
                  : '3 · COMBINACIONES',
              style: Marca.etiqueta(color: Marca.champagne)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Marca.borde),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(children: [
              for (final t in _tallesOUnico) ...[
                if (t != _tallesOUnico.first) const Divider(height: 1),
                if (!conColores)
                  _filaCantidad(
                    Prenda.clave(t, null),
                    etiqueta: Text(t == talleUnico ? 'Único' : t,
                        style: Marca.titulo(22, peso: FontWeight.w600)),
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    color: Marca.superficieAlta,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                            t == talleUnico ? 'Talle único' : 'Talle $t',
                            style: Marca.titulo(20, peso: FontWeight.w600)),
                      ),
                      if (_controlaStock)
                        Text('${_totalTalle(t)} u.',
                            style: const TextStyle(color: Marca.gris)),
                    ]),
                  ),
                  for (final c in _listaColores)
                    _filaCantidad(
                      Prenda.clave(t, c),
                      etiqueta: Row(children: [
                        const SizedBox(width: 8),
                        PuntoColor(c, tamano: 16),
                        const SizedBox(width: 10),
                        Flexible(child: Text(c)),
                      ]),
                    ),
                ],
              ],
            ]),
          ),
          const SizedBox(height: 10),
          if (_controlaStock) ...[
            Text('Total: $_stockTotalForm unidades',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'Al registrar una venta se descuenta solo del talle y color vendido. '
              'Cuando entre mercadería, sumala acá con el +.',
              style: TextStyle(color: Marca.gris, fontSize: 12),
            ),
          ] else
            const Text(
              'Sin control de stock: se puede vender siempre y no se descuenta.',
              style: TextStyle(color: Marca.gris, fontSize: 12),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esNueva = widget.prenda == null;
    final foto = _fotoBytes != null
        ? Image.memory(_fotoBytes!, fit: BoxFit.cover)
        : FotoPrenda(url: widget.prenda?.imagenUrl);

    return Scaffold(
      appBar: AppBar(title: Text(esNueva ? 'Nueva prenda' : 'Editar prenda')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: SizedBox(
                width: 220,
                height: 290,
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(12), child: foto),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _elegirFoto(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Elegir foto'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _elegirFoto(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Sacar foto'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nombre,
              decoration: const InputDecoration(labelText: 'Nombre *'),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Poné un nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _precio,
              decoration: const InputDecoration(
                  labelText: 'Precio *', prefixText: '\$ '),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) =>
                  _leerPrecio(v ?? '') == null ? 'Precio inválido' : null,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _costo,
              decoration: InputDecoration(
                labelText: 'Costo (lo que te salió) — solo lo ves vos',
                prefixText: '\$ ',
                helperText: _textoMargen(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            if (widget.rubros.isNotEmpty) ...[
              Text('RUBRO', style: Marca.etiqueta()),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final r in widget.rubros)
                  ChoiceChip(
                    label: Text(r.nombre,
                        style: TextStyle(
                            color: _rubroId == r.id
                                ? Marca.negro
                                : Marca.marfil)),
                    selected: _rubroId == r.id,
                    onSelected: (_) => setState(() => _rubroId = r.id),
                  ),
              ]),
              const SizedBox(height: 16),
            ],
            Text('¿PARA QUIÉN ES?', style: Marca.etiqueta()),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final pub in Config.publicos)
                ChoiceChip(
                  label: Text(pub,
                      style: TextStyle(
                          color: _publico == pub ? Marca.negro : Marca.marfil)),
                  selected: _publico == pub,
                  onSelected: (sel) => setState(() => _publico = sel ? pub : ''),
                ),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoria,
              decoration: const InputDecoration(
                  labelText: 'Categoría',
                  hintText: 'Ej: Remeras, Pantalones, Vestidos'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            _seccionStock(),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descripcion,
              decoration: const InputDecoration(labelText: 'Descripción'),
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _disponible,
              onChanged: (v) => setState(() => _disponible = v),
              title: const Text('Visible en el catálogo'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _guardando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Separa lo que se escribe en talles sueltos.
/// "S, M, L" · "S/M/L" · "XL-XXL" -> [S, M, L] / [XL, XXL].
/// Los rangos de números como "10-12" (talles de niños) se respetan.
List<String> separarTalles(String texto) {
  final out = <String>[];
  for (final parte in texto.split(RegExp(r'[,;/ ]+'))) {
    final p = parte.trim().toUpperCase();
    if (p.isEmpty) continue;
    final guion = p.split('-');
    final sonLetras = guion.length > 1 &&
        guion.every((g) => RegExp(r'^[0-9]*[A-Z]+$').hasMatch(g));
    out.addAll(sonLetras ? guion : [p]);
  }
  return out;
}
