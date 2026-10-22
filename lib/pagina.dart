import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'carrito.dart';
import 'catalogo.dart';
import 'config.dart';
import 'oferta.dart';
import 'pedido.dart';
import 'prenda.dart';
import 'tema.dart';

/// Página de una prenda: foto grande, talle, cantidad y botones de compra.
class PaginaPrenda extends StatefulWidget {
  const PaginaPrenda({super.key, required this.prenda});
  final Prenda prenda;

  @override
  State<PaginaPrenda> createState() => _PaginaPrendaState();
}

class _PaginaPrendaState extends State<PaginaPrenda> {
  String? _talle;
  int _cantidad = 1;
  bool _faltaTalle = false;

  bool _validarTalle() {
    final falta = widget.prenda.talles.isNotEmpty && _talle == null;
    setState(() => _faltaTalle = falta);
    return !falta;
  }

  /// Máximo que se puede pedir del talle elegido (null = sin límite).
  int? get _maximo => widget.prenda.talles.isNotEmpty && _talle == null
      ? null
      : widget.prenda.stockDe(_talle);

  Future<void> _consultarReposicion() async {
    final p = widget.prenda;
    final texto = '¡Hola ${Config.nombreTienda}! Vi "${p.nombre}" agotado. '
        '¿Va a volver a entrar?';
    await launchUrl(Uri.https('wa.me', '/${Config.whatsapp}', {'text': texto}),
        mode: LaunchMode.externalApplication);
  }

  void _agregar() {
    if (!_validarTalle()) return;
    carrito.agregar(widget.prenda, talle: _talle, cantidad: _cantidad);
    avisoAgregado(context, widget.prenda.nombre);
  }

  void _reservar() {
    if (!_validarTalle()) return;
    reservarAhora(context, widget.prenda, talle: _talle, cantidad: _cantidad);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.prenda;
    final ancho = MediaQuery.sizeOf(context).width;
    final dosColumnas = ancho > 820;

    final foto = AspectRatio(
      aspectRatio: 3 / 4,
      child: Hero(
        tag: 'foto-${p.id}',
        child: Container(
          color: Marca.superficie,
          child: FotoPrenda(url: p.imagenUrl),
        ),
      ),
    );

    final info = PanelVidrio(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (p.categoria.isNotEmpty)
              Text(p.categoria.toUpperCase(),
                  style: Marca.etiqueta(color: Marca.champagne)),
            if (p.esNueva) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: Marca.marfil,
                child: Text('NUEVO',
                    style: Marca.etiqueta(color: Marca.negro, size: 9)),
              ),
            ],
          ]),
          const SizedBox(height: 10),
          Text(p.nombre, style: Marca.titulo(dosColumnas ? 46 : 38)),
          const SizedBox(height: 12),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(p.precioFinalTexto,
                  style: Marca.titulo(34,
                      color: Marca.champagne, peso: FontWeight.w600)),
              if (p.enOferta) ...[
                Text(p.precioTexto,
                    style: const TextStyle(
                        color: Marca.gris,
                        fontSize: 16,
                        decoration: TextDecoration.lineThrough)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  color: Marca.champagne,
                  child: Text('-${p.descuentoPct}%',
                      style: Marca.etiqueta(color: Marca.negro, size: 11)),
                ),
              ],
            ],
          ),
          if (p.enOferta)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                const Icon(Icons.local_offer_outlined,
                    size: 15, color: Marca.champagne),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    [
                      p.ofertaNombre!,
                      if (textoVencimiento(p.ofertaHasta) != null)
                        textoVencimiento(p.ofertaHasta)!,
                    ].join(' · '),
                    style: const TextStyle(
                        color: Marca.champagne, fontSize: 13),
                  ),
                ),
              ]),
            ),
          if (p.talles.isNotEmpty) ...[
            const SizedBox(height: 28),
            Row(children: [
              Text('TALLE', style: Marca.etiqueta()),
              if (_faltaTalle) ...[
                const SizedBox(width: 10),
                Text('Elegí un talle',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12)),
              ],
            ]),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in p.talles)
                  _BotonTalle(
                    texto: t,
                    seleccionado: _talle == t,
                    sinStock: !p.hayStock(t),
                    onTap: () => setState(() {
                      _talle = t;
                      _faltaTalle = false;
                      _cantidad = 1;
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('CANTIDAD', style: Marca.etiqueta()),
          const SizedBox(height: 10),
          SelectorCantidad(
            valor: _cantidad,
            onMenos: () =>
                setState(() => _cantidad = (_cantidad - 1).clamp(1, 99)),
            onMas: () => setState(() {
              final max = _maximo ?? 99;
              if (_cantidad < max) _cantidad++;
            }),
          ),
          if (_maximo != null && _maximo! <= Config.stockBajo && _maximo! > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  _maximo == 1 ? '¡Queda 1 sola!' : '¡Quedan solo $_maximo!',
                  style: const TextStyle(color: Marca.champagne, fontSize: 13)),
            ),
          const SizedBox(height: 28),
          if (p.agotada) ...[
            const SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: null, child: Text('AGOTADO')),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _consultarReposicion,
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('AVISAME CUANDO VUELVA'),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _agregar,
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('AGREGAR AL PEDIDO'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _reservar,
                icon: const Icon(Icons.event_available_outlined, size: 18),
                label: const Text('RESERVAR POR WHATSAPP'),
              ),
            ),
          ],
          if (p.descripcion.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text('DESCRIPCIÓN', style: Marca.etiqueta()),
            const SizedBox(height: 10),
            Text(p.descripcion,
                style: const TextStyle(fontSize: 15, height: 1.6)),
          ],
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          InkWell(
            onTap: abrirMapa,
            child: const _Info(Icons.place_outlined,
                'Retiro en el local · ${Config.direccion} · Ver en el mapa'),
          ),
          if (Config.ofreceEnvio)
            const _Info(Icons.local_shipping_outlined,
                'Envío a domicilio a coordinar'),
          const _Info(Icons.payments_outlined,
              'Pagás en efectivo o transferencia al recibir'),
        ],
      ),
    );

    return FondoMarca(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Marca.negro.withValues(alpha: .88),
          title: Text(Config.nombreTienda,
              style: Marca.titulo(26, estilo: FontStyle.italic)),
          actions: const [BotonCarrito(), SizedBox(width: 8)],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Centrado(
            maxAncho: 1100,
            child: dosColumnas
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 11, child: foto),
                      const SizedBox(width: 32),
                      Expanded(flex: 10, child: info),
                    ],
                  )
                : Column(children: [foto, const SizedBox(height: 16), info]),
          ),
        ),
      ),
    );
  }
}

class _BotonTalle extends StatelessWidget {
  const _BotonTalle({
    required this.texto,
    required this.seleccionado,
    required this.onTap,
    this.sinStock = false,
  });
  final String texto;
  final bool seleccionado;
  final VoidCallback onTap;
  final bool sinStock;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: sinStock ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 48),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: seleccionado ? Marca.marfil : Colors.transparent,
            border:
                Border.all(color: seleccionado ? Marca.marfil : Marca.borde),
          ),
          child: Text(texto,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: sinStock ? TextDecoration.lineThrough : null,
                  color: sinStock
                      ? Marca.gris.withValues(alpha: .5)
                      : seleccionado
                          ? Marca.negro
                          : Marca.marfil)),
        ),
      );
}

class _Info extends StatelessWidget {
  const _Info(this.icono, this.texto);
  final IconData icono;
  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icono, size: 18, color: Marca.champagne),
          const SizedBox(width: 10),
          Expanded(
              child: Text(texto,
                  style: const TextStyle(color: Marca.gris, fontSize: 13))),
        ]),
      );
}
