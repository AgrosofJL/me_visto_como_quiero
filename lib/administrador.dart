import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'catalogo.dart';
import 'prenda.dart';
import 'servicio.dart';

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
// Lista de prendas para administrar
// ------------------------------------------------------------------

class _PanelAdmin extends StatefulWidget {
  const _PanelAdmin({required this.onSalir});
  final VoidCallback onSalir;

  @override
  State<_PanelAdmin> createState() => _PanelAdminState();
}

class _PanelAdminState extends State<_PanelAdmin> {
  List<Prenda> _prendas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      _prendas = await Servicio.listarPrendas();
    } catch (e) {
      _avisar('No se pudo cargar: $e');
    }
    if (mounted) setState(() => _cargando = false);
  }

  void _avisar(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _editar([Prenda? p]) async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => FormularioPrenda(prenda: p)),
    );
    if (guardado == true) _cargar();
  }

  Future<void> _borrar(Prenda p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Borrar prenda'),
        content: Text('¿Seguro que querés borrar "${p.nombre}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Servicio.borrarPrenda(p);
      _avisar('Prenda borrada');
      _cargar();
    } catch (e) {
      _avisar('No se pudo borrar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar prendas'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: widget.onSalir,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva prenda'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: _prendas.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Center(child: Text('No hay prendas. Tocá "Nueva prenda".')),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.only(bottom: 96),
                      itemCount: _prendas.length,
                      separatorBuilder: (context, i) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = _prendas[i];
                        return ListTile(
                          leading: SizedBox(
                            width: 52,
                            height: 52,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: FotoPrenda(url: p.imagenUrl),
                            ),
                          ),
                          title: Text(p.nombre),
                          subtitle: Text([
                            p.precioTexto,
                            if (p.categoria.isNotEmpty) p.categoria,
                            if (!p.disponible) 'OCULTA',
                          ].join(' · ')),
                          onTap: () => _editar(p),
                          trailing: IconButton(
                            tooltip: 'Borrar',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _borrar(p),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

// ------------------------------------------------------------------
// Formulario para crear / editar una prenda
// ------------------------------------------------------------------

class FormularioPrenda extends StatefulWidget {
  const FormularioPrenda({super.key, this.prenda});
  final Prenda? prenda;

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
  late final _talles =
      TextEditingController(text: widget.prenda?.talles.join(', '));
  late bool _disponible = widget.prenda?.disponible ?? true;

  XFile? _fotoNueva;
  Uint8List? _fotoBytes;
  bool _guardando = false;

  static String _numATexto(double v) =>
      v == v.truncateToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    for (final c in [_nombre, _descripcion, _precio, _categoria, _talles]) {
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
        talles: _talles.text
            .split(',')
            .map((t) => t.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
        imagenUrl: url,
        imagenPath: ruta,
        disponible: _disponible,
      );
      await Servicio.guardarPrenda(prenda);

      // Si se cambió la foto, borra la anterior para no ocupar espacio.
      if (rutaVieja != null && rutaVieja != ruta) {
        await Servicio.borrarFoto(rutaVieja);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
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
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _categoria,
              decoration: const InputDecoration(
                  labelText: 'Categoría',
                  hintText: 'Ej: Remeras, Pantalones, Vestidos'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _talles,
              decoration: const InputDecoration(
                  labelText: 'Talles', hintText: 'Separados por coma: S, M, L'),
              textCapitalization: TextCapitalization.characters,
            ),
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
