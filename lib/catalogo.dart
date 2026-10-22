import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'administrador.dart';
import 'carrito.dart';
import 'colores.dart';
import 'config.dart';
import 'oferta.dart';
import 'pagina.dart';
import 'prenda.dart';
import 'rubro.dart';
import 'servicio.dart';
import 'tema.dart';

/// Pantalla principal de la tienda.
class CatalogoPage extends StatefulWidget {
  const CatalogoPage({super.key});

  @override
  State<CatalogoPage> createState() => _CatalogoPageState();
}

class _CatalogoPageState extends State<CatalogoPage> {
  final _claveColeccion = GlobalKey();
  List<Prenda> _prendas = [];
  bool _cargando = true;
  String? _error;
  String _categoria = 'Todo';
  String _busqueda = '';
  String _orden = 'Novedades';
  String _publico = 'Todo';
  bool _soloOfertas = false;
  List<Rubro> _rubros = [];
  String? _rubroId; // null = todos

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await Servicio.catalogo();
      try {
        _rubros = await Servicio.listarRubros();
      } catch (_) {
        _rubros = []; // Todavía no se corrió 04_rubros.sql
      }
      if (!mounted) return;
      setState(() => _prendas = lista.where((p) => p.disponible).toList());
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pudimos cargar el catálogo.\nRevisá tu conexión.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Prendas del rubro y público elegidos (base para categorías y grilla).
  Iterable<Prenda> get _enSeccion => _prendas.where((p) =>
      (_rubroId == null || p.rubroId == _rubroId) &&
      _coincidePublico(p, _publico));

  /// Rubros que tienen al menos una prenda visible, en el orden configurado.
  List<Rubro> get _rubrosConPrendas =>
      _rubros.where((r) => _prendas.any((p) => p.rubroId == r.id)).toList();

  List<String> get _categorias {
    final set = _enSeccion
        .map((p) => p.categoria.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Todo', ...set];
  }

  List<Prenda> get _filtradas {
    final q = _busqueda.toLowerCase().trim();
    final lista = _prendas.where((p) {
      final okCat = _categoria == 'Todo' || p.categoria.trim() == _categoria;
      final okRubro = _rubroId == null || p.rubroId == _rubroId;
      final okPub = _coincidePublico(p, _publico);
      final okOferta = !_soloOfertas || p.enOferta;
      final okBusq = q.isEmpty ||
          p.nombre.toLowerCase().contains(q) ||
          p.descripcion.toLowerCase().contains(q) ||
          p.categoria.toLowerCase().contains(q);
      return okCat && okBusq && okPub && okOferta && okRubro;
    }).toList();
    switch (_orden) {
      case 'Menor precio':
        lista.sort((a, b) => a.precioFinal.compareTo(b.precioFinal));
      case 'Mayor precio':
        lista.sort((a, b) => b.precioFinal.compareTo(a.precioFinal));
    }
    return lista;
  }

  /// "Unisex" también aparece al filtrar Mujer u Hombre.
  static bool _coincidePublico(Prenda p, String publico) {
    if (publico == 'Todo') return true;
    if (p.publico == publico) return true;
    return p.publico == 'Unisex' && (publico == 'Mujer' || publico == 'Hombre');
  }

  List<String> get _publicosDisponibles => [
        'Todo',
        for (final pub in Config.publicos)
          if (_prendas.any((p) =>
              p.publico == pub &&
              (_rubroId == null || p.rubroId == _rubroId)))
            pub,
      ];

  void _verOfertas() {
    setState(() {
      _soloOfertas = true;
      _categoria = 'Todo';
    });
    _irAColeccion();
  }

  void _irAColeccion() {
    final ctx = _claveColeccion.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic);
    }
  }

  Future<void> _abrirAdmin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdministradorPage()),
    );
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final tam = MediaQuery.sizeOf(context);
    final margen = math.max(16.0, (tam.width - 1200) / 2);
    final columnas = tam.width > 1100
        ? 4
        : tam.width > 760
            ? 3
            : 2;

    return FondoMarca(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _cargar,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  _barraSuperior(),
                  SliverToBoxAdapter(child: _hero(tam)),
                  SliverToBoxAdapter(
                    child: Padding(
                      key: _claveColeccion,
                      padding: EdgeInsets.fromLTRB(margen, 8, margen, 0),
                      child: _filtros(),
                    ),
                  ),
                  ..._grilla(margen, columnas),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(margen, 40, margen, 120),
                      child: _PiePagina(onAdmin: _abrirAdmin),
                    ),
                  ),
                ],
              ),
            ),
            const _BarraPedido(),
          ],
        ),
      ),
    );
  }

  Widget _barraSuperior() => SliverAppBar(
        pinned: true,
        backgroundColor: Marca.negro.withValues(alpha: .88),
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        titleSpacing: 16,
        centerTitle: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/logo_blanco.png', height: 40),
            const SizedBox(width: 10),
            Text(Config.nombreTienda,
                style: Marca.titulo(28,
                    estilo: FontStyle.italic, peso: FontWeight.w600)),
          ],
        ),
        actions: const [BotonCarrito(), SizedBox(width: 8)],
      );

  Widget _hero(Size tam) {
    final grande = tam.width > 760;
    return SizedBox(
      height: math.max(380, tam.height * .68),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, .55, 1],
            colors: [Colors.transparent, Colors.transparent, Color(0xE60B0B0B)],
          ),
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Config.subtitulo.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: Marca.etiqueta(color: Marca.champagne)),
                const SizedBox(height: 12),
                Text(Config.eslogan,
                    textAlign: TextAlign.center,
                    style: Marca.titulo(grande ? 72 : 46,
                        estilo: FontStyle.italic, peso: FontWeight.w500)),
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton(
                      onPressed: _irAColeccion,
                      child: const Text('VER COLECCIÓN'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.https('wa.me', '/${Config.whatsapp}'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('ESCRIBINOS'),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 22,
                  runSpacing: 8,
                  children: [
                    InkWell(
                      onTap: abrirMapa,
                      child: const _Beneficio(
                          Icons.place_outlined, 'Retiro en el local · Ver mapa'),
                    ),
                    if (Config.ofreceEnvio)
                      const _Beneficio(Icons.local_shipping_outlined, 'Envíos a domicilio'),
                    const _Beneficio(Icons.payments_outlined, 'Efectivo o transferencia'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bannerOfertas() {
    final enOferta = _prendas.where((p) => p.enOferta).toList();
    if (enOferta.isEmpty) return const SizedBox.shrink();
    final nombres = enOferta.map((p) => p.ofertaNombre!).toSet().toList();
    final maxDesc = enOferta.map((p) => p.descuentoPct).reduce(math.max);
    final vencimientos = enOferta
        .map((p) => p.ofertaHasta)
        .whereType<DateTime>()
        .toList()
      ..sort();
    final vence =
        vencimientos.isEmpty ? null : textoVencimiento(vencimientos.first);

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: InkWell(
        onTap: _verOfertas,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Marca.champagne, Marca.champagneOscuro],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombres.join(' · ').toUpperCase(),
                        style: Marca.etiqueta(color: Marca.negro)),
                    const SizedBox(height: 4),
                    Text('Hasta $maxDesc% OFF',
                        style: Marca.titulo(36,
                            color: Marca.negro, peso: FontWeight.w700)),
                    Text(
                      '${enOferta.length} prendas en oferta'
                      '${vence != null ? ' · $vence' : ''}',
                      style: const TextStyle(color: Marca.negro),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                color: Marca.negro,
                child: Text('VER OFERTAS',
                    style: Marca.etiqueta(color: Marca.marfil, size: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectorRubros() {
    final rubros = _rubrosConPrendas;
    if (rubros.length <= 1) return const SizedBox.shrink();
    Widget boton(String? id, String nombre) {
      final sel = _rubroId == id;
      return Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: () => setState(() {
            _rubroId = id;
            _categoria = 'Todo';
            _publico = 'Todo';
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: sel ? Marca.marfil : Colors.black.withValues(alpha: .35),
              border: Border.all(color: sel ? Marca.marfil : Marca.borde),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(nombre,
                style: Marca.titulo(22,
                    peso: FontWeight.w600,
                    color: sel ? Marca.negro : Marca.marfil)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿QUÉ ESTÁS BUSCANDO?',
              style: Marca.etiqueta(color: Marca.champagne)),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                boton(null, 'Todo'),
                for (final r in rubros) boton(r.id, r.nombre),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pestanasPublico() {
    final pubs = _publicosDisponibles;
    if (pubs.length <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final pub in pubs)
              InkWell(
                onTap: () => setState(() {
                  _publico = pub;
                  _categoria = 'Todo';
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        width: 2,
                        color: _publico == pub
                            ? Marca.champagne
                            : Colors.transparent,
                      ),
                    ),
                  ),
                  child: Text(
                    pub.toUpperCase(),
                    style: Marca.etiqueta(
                      size: 13,
                      color: _publico == pub ? Marca.marfil : Marca.gris,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _filtros() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bannerOfertas(),
        _selectorRubros(),
        _pestanasPublico(),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      _soloOfertas
                          ? 'SOLO'
                          : _publico == 'Todo'
                              ? 'NUESTRA'
                              : _publico.toUpperCase(),
                      style: Marca.etiqueta(color: Marca.champagne)),
                  const SizedBox(height: 4),
                  Text(
                      _soloOfertas
                          ? 'Ofertas'
                          : _rubroId != null
                              ? _rubros
                                  .firstWhere((r) => r.id == _rubroId,
                                      orElse: () =>
                                          const Rubro(nombre: 'Colección'))
                                  .nombre
                              : 'Colección',
                      style: Marca.titulo(44)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Ordenar',
              initialValue: _orden,
              onSelected: (v) => setState(() => _orden = v),
              itemBuilder: (_) => [
                for (final o in ['Novedades', 'Menor precio', 'Mayor precio'])
                  PopupMenuItem(value: o, child: Text(o)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(_orden, style: const TextStyle(color: Marca.gris)),
                  const Icon(Icons.expand_more, color: Marca.gris),
                ]),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Buscar remeras, jeans, vestidos…',
            prefixIcon: Icon(Icons.search, color: Marca.gris),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        if (_categorias.length > 1 || _prendas.any((p) => p.enOferta)) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _categorias.length + 1,
              separatorBuilder: (context, i) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return FilterChip(
                    avatar: Icon(Icons.local_offer_outlined,
                        size: 16,
                        color: _soloOfertas ? Marca.negro : Marca.champagne),
                    label: Text('Ofertas',
                        style: TextStyle(
                            color:
                                _soloOfertas ? Marca.negro : Marca.champagne)),
                    selected: _soloOfertas,
                    selectedColor: Marca.champagne,
                    side: const BorderSide(color: Marca.champagne),
                    showCheckmark: false,
                    onSelected: (v) => setState(() => _soloOfertas = v),
                  );
                }
                final c = _categorias[i - 1];
                final sel = _categoria == c;
                return ChoiceChip(
                  label: Text(c,
                      style:
                          TextStyle(color: sel ? Marca.negro : Marca.marfil)),
                  selected: sel,
                  onSelected: (_) => setState(() => _categoria = c),
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  List<Widget> _grilla(double margen, int columnas) {
    Widget mensaje(Widget hijo) => SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: margen, vertical: 40),
            child: PanelVidrio(
                padding: const EdgeInsets.all(32), child: Center(child: hijo)),
          ),
        );

    if (_cargando && _prendas.isEmpty) {
      return [
        mensaje(const CircularProgressIndicator(color: Marca.champagne)),
      ];
    }
    if (_error != null) {
      return [
        mensaje(Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: _cargar, child: const Text('REINTENTAR')),
        ])),
      ];
    }
    final lista = _filtradas;
    if (lista.isEmpty) {
      return [
        mensaje(Text(
          _prendas.isEmpty
              ? 'Muy pronto vas a ver nuestras prendas acá ✨'
              : 'No encontramos prendas con esa búsqueda.',
          textAlign: TextAlign.center,
        )),
      ];
    }
    return [
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: margen),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columnas,
            mainAxisSpacing: 20,
            crossAxisSpacing: 14,
            childAspectRatio: .56,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, i) => TarjetaPrenda(prenda: lista[i]),
            childCount: lista.length,
          ),
        ),
      ),
    ];
  }
}

class _Beneficio extends StatelessWidget {
  const _Beneficio(this.icono, this.texto);
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: Marca.champagne),
          const SizedBox(width: 6),
          Text(texto, style: const TextStyle(color: Marca.gris, fontSize: 13)),
        ],
      );
}

/// Tarjeta de una prenda en la grilla.
class TarjetaPrenda extends StatefulWidget {
  const TarjetaPrenda({super.key, required this.prenda});
  final Prenda prenda;

  @override
  State<TarjetaPrenda> createState() => _TarjetaPrendaState();
}

class _TarjetaPrendaState extends State<TarjetaPrenda> {
  bool _hover = false;

  void _abrir() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PaginaPrenda(prenda: widget.prenda)),
      );

  void _agregarRapido() {
    final p = widget.prenda;
    if (p.agotada) return;
    if (p.talles.isNotEmpty || p.colores.isNotEmpty || !p.hayStock(null)) {
      _abrir(); // tiene talles: que elija en la página de la prenda
      return;
    }
    carrito.agregar(p);
    avisoAgregado(context, p.nombre);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prenda;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _abrir,
        child: Container(
          color: Marca.superficie,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRect(
                      child: AnimatedScale(
                        scale: _hover ? 1.05 : 1,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        child: Hero(
                          tag: 'foto-${p.id}',
                          child: FotoPrenda(url: p.imagenUrl),
                        ),
                      ),
                    ),
                    if (p.agotada)
                      Container(
                        color: Colors.black.withValues(alpha: .55),
                        alignment: Alignment.center,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              border: Border.all(color: Marca.marfil)),
                          child: Text('AGOTADO',
                              style: Marca.etiqueta(
                                  color: Marca.marfil, size: 11)),
                        ),
                      ),
                    if (!p.agotada &&
                        p.controlaStock &&
                        p.stockTotal <= Config.stockBajo)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          color: Marca.champagne,
                          child: Text('ÚLTIMAS',
                              style: Marca.etiqueta(
                                  color: Marca.negro, size: 10)),
                        ),
                      ),
                    if (p.enOferta)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          color: Marca.champagne,
                          child: Text('-${p.descuentoPct}%',
                              style: Marca.etiqueta(
                                  color: Marca.negro, size: 11)),
                        ),
                      ),
                    if (p.esNueva && !p.enOferta)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          color: Marca.marfil,
                          child: Text('NUEVO',
                              style: Marca.etiqueta(
                                  color: Marca.negro, size: 10)),
                        ),
                      ),
                    if (!p.agotada)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Material(
                        color: Marca.negro.withValues(alpha: .75),
                        shape: const CircleBorder(),
                        child: IconButton(
                          tooltip: 'Agregar al pedido',
                          onPressed: _agregarRapido,
                          icon: const Icon(Icons.add_shopping_cart,
                              size: 18, color: Marca.marfil),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.categoria.isNotEmpty)
                      Text(p.categoria.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Marca.etiqueta(size: 9)),
                    const SizedBox(height: 4),
                    Text(
                      p.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(p.precioFinalTexto,
                            style: Marca.titulo(22,
                                color: Marca.champagne,
                                peso: FontWeight.w600)),
                        if (p.enOferta)
                          Text(p.precioTexto,
                              style: const TextStyle(
                                  color: Marca.gris,
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough)),
                      ],
                    ),
                    if (p.colores.length > 1) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        for (final c in p.colores.take(6))
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Tooltip(
                                message: c, child: PuntoColor(c, tamano: 12)),
                          ),
                        if (p.colores.length > 6)
                          Text('+${p.colores.length - 6}',
                              style: const TextStyle(
                                  color: Marca.gris, fontSize: 11)),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void avisoAgregado(BuildContext context, String nombre) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('Agregaste "$nombre" a tu pedido'),
        action: SnackBarAction(
          label: 'VER PEDIDO',
          textColor: Marca.negro,
          onPressed: () => abrirCarrito(context),
        ),
      ),
    );
}

/// Barra flotante abajo cuando hay prendas en el pedido.
class _BarraPedido extends StatelessWidget {
  const _BarraPedido();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: carrito,
      builder: (context, _) => AnimatedPositioned(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        left: 16,
        right: 16,
        bottom: carrito.vacio ? -100 : 16,
        child: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: Marca.marfil,
                elevation: 8,
                borderRadius: BorderRadius.circular(2),
                child: InkWell(
                  onTap: () => abrirCarrito(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined,
                            color: Marca.negro),
                        const SizedBox(width: 12),
                        Text(
                          'VER MI PEDIDO (${carrito.cantidadTotal})',
                          style: Marca.etiqueta(color: Marca.negro, size: 12),
                        ),
                        const Spacer(),
                        Text(formatearPrecio(carrito.total),
                            style: const TextStyle(
                                color: Marca.negro,
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PiePagina extends StatelessWidget {
  const _PiePagina({required this.onAdmin});
  final VoidCallback onAdmin;

  @override
  Widget build(BuildContext context) {
    final columnas = MediaQuery.sizeOf(context).width > 760;
    final bloques = [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(Config.nombreTienda,
              style: Marca.titulo(36,
                  estilo: FontStyle.italic, peso: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(Config.eslogan, style: const TextStyle(color: Marca.gris)),
        ],
      ),
      InkWell(
        onTap: abrirMapa,
        child: const _DatoPie(Icons.place_outlined, 'DÓNDE',
            '${Config.direccion}\nVer en el mapa →'),
      ),
      _DatoPie(Icons.schedule, 'HORARIO', Config.horario),
      InkWell(
        onTap: () => launchUrl(Uri.https('wa.me', '/${Config.whatsapp}'),
            mode: LaunchMode.externalApplication),
        child: _DatoPie(Icons.chat_outlined, 'WHATSAPP', Config.whatsappVisible),
      ),
    ];

    return PanelVidrio(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (columnas)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final b in bloques) Expanded(child: b),
              ],
            )
          else
            for (final b in bloques)
              Padding(padding: const EdgeInsets.only(bottom: 20), child: b),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                    '© ${DateTime.now().year} ${Config.nombreTienda}',
                    style: const TextStyle(color: Marca.gris, fontSize: 12)),
              ),
              TextButton.icon(
                onPressed: onAdmin,
                icon: const Icon(Icons.lock_outline, size: 14, color: Marca.gris),
                label: const Text('Administrar',
                    style: TextStyle(color: Marca.gris, fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatoPie extends StatelessWidget {
  const _DatoPie(this.icono, this.titulo, this.texto);
  final IconData icono;
  final String titulo;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icono, size: 14, color: Marca.champagne),
              const SizedBox(width: 6),
              Text(titulo, style: Marca.etiqueta(color: Marca.champagne)),
            ]),
            const SizedBox(height: 8),
            Text(texto, style: const TextStyle(height: 1.4)),
          ],
        ),
      );
}

/// Foto de una prenda con un fondo neutro si no tiene imagen o falla.
class FotoPrenda extends StatelessWidget {
  const FotoPrenda({super.key, this.url, this.fit = BoxFit.cover});
  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final vacio = Container(
      color: Marca.superficieAlta,
      alignment: Alignment.center,
      child: const Icon(Icons.checkroom, size: 44, color: Color(0x33FFFFFF)),
    );
    if (url == null || url!.isEmpty) return vacio;
    return Image.network(
      url!,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stack) => vacio,
      frameBuilder: (context, child, frame, sincrono) {
        if (sincrono) return child;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: frame == null ? vacio : child,
        );
      },
    );
  }
}
