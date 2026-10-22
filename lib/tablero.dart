import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'config.dart';
import 'prenda.dart';
import 'servicio.dart';
import 'tema.dart';
import 'venta.dart';

const _verde = Color(0xFF7BC47F);
const _rojo = Color(0xFFE57373);
const _ambar = Color(0xFFE0B354);

/// Tablero de control: ventas, ingresos, ganancia y stock.
class TableroTab extends StatefulWidget {
  const TableroTab({super.key});

  @override
  State<TableroTab> createState() => TableroTabState();
}

class TableroTabState extends State<TableroTab> {
  Periodo _periodo = Periodo.esteMes();
  List<Venta> _ventas = [];
  List<Venta> _anteriores = [];
  List<Prenda> _prendas = [];
  Map<String, double> _costos = {};
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
      final ant = _periodo.anterior;
      final r = await Future.wait([
        Servicio.listarVentas(_periodo.desde, _periodo.hasta),
        Servicio.listarVentas(ant.desde, ant.hasta),
        Servicio.listarPrendas(),
        Servicio.listarCostos(),
      ]);
      _ventas = (r[0] as List<Venta>).where((v) => !v.anulada).toList();
      _anteriores = (r[1] as List<Venta>).where((v) => !v.anulada).toList();
      _prendas = r[2] as List<Prenda>;
      _costos = r[3] as Map<String, double>;
    } catch (e) {
      _error = mensajeError(e);
    }
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 6),
          Text(_periodo.descripcion, style: const TextStyle(color: Marca.gris)),
          const SizedBox(height: 14),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.all(60),
              child: Center(
                  child: CircularProgressIndicator(color: Marca.champagne)),
            )
          else if (_error != null)
            Tarjeta(
              child: Column(children: [
                Text('No se pudo cargar el tablero:\n$_error',
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text(
                    '¿Corriste supabase/02_stock_ventas.sql en Supabase?',
                    style: TextStyle(color: Marca.gris)),
                const SizedBox(height: 12),
                OutlinedButton(
                    onPressed: recargar, child: const Text('REINTENTAR')),
              ]),
            )
          else
            ..._contenido(),
        ],
      ),
    );
  }

  List<Widget> _contenido() {
    final ingresos = _sum(_ventas, (v) => v.total);
    final ingresosAnt = _sum(_anteriores, (v) => v.total);
    final costo = _sum(_ventas, (v) => v.costoTotal);
    final ganancia = ingresos - costo;
    final gananciaAnt = _sum(_anteriores, (v) => v.ganancia);
    final tickets = _ventas.length;
    final unidades = _ventas.fold<int>(0, (s, v) => s + v.unidades);
    final unidadesAnt = _anteriores.fold<int>(0, (s, v) => s + v.unidades);
    final ticketProm = tickets == 0 ? 0.0 : ingresos / tickets;
    final ticketPromAnt =
        _anteriores.isEmpty ? 0.0 : ingresosAnt / _anteriores.length;
    final hayCostos = _ventas.any((v) => v.costoTotal > 0);

    // Stock
    var stockUnidades = 0;
    var valorVenta = 0.0;
    var valorCosto = 0.0;
    final sinStock = <(Prenda, String)>[];
    final bajo = <(Prenda, String, int)>[];
    for (final p in _prendas.where((p) => p.controlaStock)) {
      for (final t in p.clavesStock) {
        final n = p.stock[t] ?? 0;
        stockUnidades += n;
        valorVenta += n * p.precio;
        valorCosto += n * (_costos[p.id] ?? 0);
        if (n <= 0) {
          sinStock.add((p, t));
        } else if (n <= Config.stockBajo) {
          bajo.add((p, t, n));
        }
      }
    }

    final ancho = MediaQuery.sizeOf(context).width;
    final cols = ancho > 1000 ? 4 : 2;
    final dosColumnas = ancho > 900;

    final kpis = [
      _Kpi(
        titulo: 'Ingresos',
        valor: formatearPrecio(ingresos),
        variacion: _var(ingresos, ingresosAnt),
        icono: Icons.payments_outlined,
        destacado: true,
      ),
      _Kpi(
        titulo: 'Ganancia',
        valor: hayCostos ? formatearPrecio(ganancia) : '—',
        variacion: hayCostos ? _var(ganancia, gananciaAnt) : null,
        detalle: hayCostos && ingresos > 0
            ? 'Margen ${(ganancia / ingresos * 100).round()}%'
            : 'Cargá el costo en las prendas',
        icono: Icons.trending_up,
      ),
      _Kpi(
        titulo: 'Ventas',
        valor: '$tickets',
        variacion: _var(tickets.toDouble(), _anteriores.length.toDouble()),
        detalle: 'Ticket prom. ${formatearPrecio(ticketProm)}',
        icono: Icons.receipt_long_outlined,
      ),
      _Kpi(
        titulo: 'Prendas vendidas',
        valor: '$unidades',
        variacion: _var(unidades.toDouble(), unidadesAnt.toDouble()),
        detalle: ticketPromAnt > 0 ? 'Período anterior: $unidadesAnt' : null,
        icono: Icons.checkroom_outlined,
      ),
    ];

    final grafico = Tarjeta(
      titulo: 'Ingresos por ${_agruparPorMes ? 'mes' : 'día'}',
      child: _GraficoBarras(datos: _serie()),
    );

    final pagos = Tarjeta(
      titulo: 'Por forma de pago',
      child: _distribucion((v) => [v.formaPago], ingresos),
    );
    final canales = Tarjeta(
      titulo: 'Por canal',
      child: _distribucion((v) => [v.canal], ingresos),
    );
    final top = Tarjeta(titulo: 'Más vendidas', child: _topPrendas());
    final rubros = Tarjeta(titulo: 'Por rubro', child: _porRubro(ingresos));
    final categorias =
        Tarjeta(titulo: 'Por categoría', child: _porCategoria(ingresos));

    final stock = Tarjeta(
      titulo: 'Stock',
      child: Column(children: [
        _filaDato('Prendas en stock', '$stockUnidades u.'),
        _filaDato('Valor a precio de venta', formatearPrecio(valorVenta)),
        if (valorCosto > 0)
          _filaDato('Valor a costo (inversión)', formatearPrecio(valorCosto)),
        if (valorCosto > 0)
          _filaDato('Ganancia potencial',
              formatearPrecio(valorVenta - valorCosto)),
      ]),
    );

    final alertas = Tarjeta(
      titulo: 'Alertas de stock',
      child: sinStock.isEmpty && bajo.isEmpty
          ? const SinDatos('Todo en orden 👌')
          : Column(children: [
              for (final s in sinStock.take(12))
                _alerta(s.$1, s.$2, 0, _rojo),
              for (final b in bajo.take(12)) _alerta(b.$1, b.$2, b.$3, _ambar),
              if (sinStock.length + bajo.length > 24)
                const Text('…y más', style: TextStyle(color: Marca.gris)),
            ]),
    );

    Widget fila(List<Widget> w) => dosColumnas
        ? Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < w.length; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(child: w[i]),
                  ],
                ],
              ),
            ),
          )
        : Column(children: [
            for (final x in w)
              Padding(padding: const EdgeInsets.only(bottom: 14), child: x),
          ]);

    return [
      GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: cols == 4 ? 1.7 : 1.25,
        children: kpis,
      ),
      const SizedBox(height: 14),
      Padding(padding: const EdgeInsets.only(bottom: 14), child: grafico),
      fila([rubros, categorias]),
      fila([pagos, canales]),
      fila([top, stock]),
      alertas,
    ];
  }

  // ---------------- cálculos ----------------

  static double _sum(List<Venta> l, double Function(Venta) f) =>
      l.fold<double>(0, (s, v) => s + f(v));

  /// Variación % respecto al período anterior (null si no hay base).
  static double? _var(double actual, double anterior) {
    if (anterior <= 0) return null;
    return (actual - anterior) / anterior * 100;
  }

  bool get _agruparPorMes => _periodo.dias > 62;

  List<(String, double)> _serie() {
    final manana = soloDia(DateTime.now()).add(const Duration(days: 1));
    final fin = _periodo.hasta.isAfter(manana) ? manana : _periodo.hasta;
    if (_agruparPorMes) {
      const meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
      final out = <(String, double)>[];
      var m = DateTime(_periodo.desde.year, _periodo.desde.month, 1);
      while (m.isBefore(fin)) {
        final sig = DateTime(m.year, m.month + 1, 1);
        final total = _ventas
            .where((v) => !v.fecha.isBefore(m) && v.fecha.isBefore(sig))
            .fold<double>(0, (s, v) => s + v.total);
        out.add((meses[m.month - 1], total));
        m = sig;
      }
      return out;
    }
    final out = <(String, double)>[];
    var d = _periodo.desde;
    while (d.isBefore(fin)) {
      final dia = d;
      final total = _ventas
          .where((v) => soloDia(v.fecha) == dia)
          .fold<double>(0, (s, v) => s + v.total);
      out.add((fechaDiaMes(dia), total));
      d = DateTime(d.year, d.month, d.day + 1);
    }
    return out;
  }

  Widget _distribucion(List<String> Function(Venta) clave, double total) {
    final mapa = <String, double>{};
    final cant = <String, int>{};
    for (final v in _ventas) {
      for (final k in clave(v)) {
        final key = k.isEmpty ? 'Sin dato' : k;
        mapa[key] = (mapa[key] ?? 0) + v.total;
        cant[key] = (cant[key] ?? 0) + 1;
      }
    }
    if (mapa.isEmpty) return const SinDatos('Sin ventas en el período');
    final orden = mapa.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(children: [
      for (final e in orden)
        BarraValor(
          etiqueta: e.key,
          valorTexto: formatearPrecio(e.value),
          detalle: '${total > 0 ? (e.value / total * 100).round() : 0}% · ${cant[e.key]} vtas',
          proporcion: total > 0 ? e.value / total : 0,
        ),
    ]);
  }

  Widget _topPrendas() {
    final unidades = <String, int>{};
    final plata = <String, double>{};
    for (final v in _ventas) {
      for (final i in v.items) {
        unidades[i.nombre] = (unidades[i.nombre] ?? 0) + i.cantidad;
        plata[i.nombre] = (plata[i.nombre] ?? 0) + i.subtotal;
      }
    }
    if (unidades.isEmpty) return const SinDatos('Sin ventas en el período');
    final orden = unidades.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maximo = orden.first.value.toDouble();
    return Column(children: [
      for (final e in orden.take(6))
        BarraValor(
          etiqueta: e.key,
          valorTexto: '${e.value} u.',
          detalle: formatearPrecio(plata[e.key] ?? 0),
          proporcion: e.value / maximo,
          color: Marca.marfil,
        ),
    ]);
  }

  Widget _porRubro(double total) {
    final mapa = <String, double>{};
    final unidades = <String, int>{};
    for (final v in _ventas) {
      for (final i in v.items) {
        final k = i.rubro.isEmpty ? 'Sin rubro' : i.rubro;
        mapa[k] = (mapa[k] ?? 0) + i.subtotal;
        unidades[k] = (unidades[k] ?? 0) + i.cantidad;
      }
    }
    if (mapa.isEmpty) return const SinDatos('Sin ventas en el período');
    final orden = mapa.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(children: [
      for (final e in orden)
        BarraValor(
          etiqueta: e.key,
          valorTexto: formatearPrecio(e.value),
          detalle: '${total > 0 ? (e.value / total * 100).round() : 0}% · ${unidades[e.key]} u.',
          proporcion: total > 0 ? e.value / total : 0,
          color: Marca.marfil,
        ),
    ]);
  }

  Widget _porCategoria(double total) {
    final mapa = <String, double>{};
    for (final v in _ventas) {
      for (final i in v.items) {
        final k = i.categoria.isEmpty ? 'Sin categoría' : i.categoria;
        mapa[k] = (mapa[k] ?? 0) + i.subtotal;
      }
    }
    if (mapa.isEmpty) return const SinDatos('Sin ventas en el período');
    final orden = mapa.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(children: [
      for (final e in orden.take(8))
        BarraValor(
          etiqueta: e.key,
          valorTexto: formatearPrecio(e.value),
          detalle: total > 0 ? '${(e.value / total * 100).round()}%' : null,
          proporcion: total > 0 ? e.value / total : 0,
        ),
    ]);
  }

  Widget _filaDato(String a, String b) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(a, style: const TextStyle(color: Marca.gris))),
          Text(b, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _alerta(Prenda p, String talle, int n, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                talle == talleUnico
                    ? p.nombre
                    : '${p.nombre} · ${etiquetaVariante(talle)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          Text(n == 0 ? 'SIN STOCK' : 'Quedan $n',
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

class _Kpi extends StatelessWidget {
  const _Kpi({
    required this.titulo,
    required this.valor,
    required this.icono,
    this.variacion,
    this.detalle,
    this.destacado = false,
  });
  final String titulo;
  final String valor;
  final IconData icono;
  final double? variacion;
  final String? detalle;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final v = variacion;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: destacado ? Marca.champagne : Marca.superficie,
        border: Border.all(color: destacado ? Marca.champagne : Marca.borde),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icono,
                size: 18, color: destacado ? Marca.negro : Marca.champagne),
            const SizedBox(width: 8),
            Expanded(
              child: Text(titulo.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Marca.etiqueta(
                      size: 10,
                      color: destacado ? Marca.negro : Marca.gris)),
            ),
          ]),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(valor,
                style: Marca.titulo(34,
                    peso: FontWeight.w600,
                    color: destacado ? Marca.negro : Marca.marfil)),
          ),
          const SizedBox(height: 4),
          Row(children: [
            if (v != null) ...[
              Icon(v >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 13,
                  color: destacado
                      ? Marca.negro
                      : (v >= 0 ? _verde : _rojo)),
              Text('${v.abs().round()}%',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: destacado
                          ? Marca.negro
                          : (v >= 0 ? _verde : _rojo))),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                detalle ?? (v != null ? 'vs. período anterior' : ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    color: destacado ? Marca.negro : Marca.gris),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

/// Gráfico de barras simple, sin librerías externas.
class _GraficoBarras extends StatelessWidget {
  const _GraficoBarras({required this.datos});
  final List<(String, double)> datos;

  @override
  Widget build(BuildContext context) {
    if (datos.isEmpty || datos.every((d) => d.$2 == 0)) {
      return const SizedBox(
          height: 180, child: SinDatos('Todavía no hay ventas para graficar'));
    }
    final maximo = datos.map((d) => d.$2).reduce(math.max);
    // Cada cuántas barras se muestra la etiqueta de abajo
    final paso = (datos.length / 10).ceil().clamp(1, 1000);

    return SizedBox(
      height: 220,
      child: Column(
        children: [
          Row(children: [
            Text(formatearPrecio(maximo),
                style: const TextStyle(color: Marca.gris, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in datos)
                  Expanded(
                    child: Tooltip(
                      message: '${d.$1}: ${formatearPrecio(d.$2)}',
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: datos.length > 40 ? .5 : 2),
                        child: FractionallySizedBox(
                          heightFactor: maximo > 0
                              ? math.max(d.$2 / maximo, d.$2 > 0 ? .02 : 0.0)
                              : 0.0,
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: d.$2 == maximo
                                  ? Marca.champagne
                                  : Marca.champagne.withValues(alpha: .55),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 6),
          Row(children: [
            for (var i = 0; i < datos.length; i++)
              Expanded(
                child: i % paso == 0
                    ? Text(datos[i].$1,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        style: const TextStyle(
                            color: Marca.gris, fontSize: 9))
                    : const SizedBox(),
              ),
          ]),
        ],
      ),
    );
  }
}
