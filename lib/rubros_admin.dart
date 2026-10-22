import 'package:flutter/material.dart';

import 'admin_ui.dart';
import 'carrito.dart' show confirmar;
import 'rubro.dart';
import 'servicio.dart';
import 'tema.dart';

/// Administrar los rubros: Ropa, Bijouterie, Ropa interior, Accesorios...
class RubrosPage extends StatefulWidget {
  const RubrosPage({super.key});

  @override
  State<RubrosPage> createState() => _RubrosPageState();
}

class _RubrosPageState extends State<RubrosPage> {
  List<Rubro> _rubros = [];
  bool _cargando = true;
  String? _error;

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
      _rubros = await Servicio.listarRubros();
    } catch (e) {
      _error = mensajeError(e);
    }
    if (mounted) setState(() => _cargando = false);
  }

  Future<String?> _pedirNombre({String inicial = '', required String titulo}) {
    final ctrl = TextEditingController(text: inicial);
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Nombre', hintText: 'Ej: Bijouterie, Calzado, Carteras'),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text('Guardar')),
        ],
      ),
    );
  }

  Future<void> _nuevo() async {
    final nombre = (await _pedirNombre(titulo: 'Nuevo rubro'))?.trim();
    if (nombre == null || nombre.isEmpty) return;
    try {
      await Servicio.guardarRubro(
          Rubro(nombre: nombre, orden: _rubros.length + 1));
      _cargar();
    } catch (e) {
      if (mounted) avisar(context, _mensaje(e));
    }
  }

  Future<void> _renombrar(Rubro r) async {
    final nombre =
        (await _pedirNombre(inicial: r.nombre, titulo: 'Renombrar rubro'))
            ?.trim();
    if (nombre == null || nombre.isEmpty || nombre == r.nombre) return;
    try {
      await Servicio.guardarRubro(
          Rubro(id: r.id, nombre: nombre, orden: r.orden));
      _cargar();
    } catch (e) {
      if (mounted) avisar(context, _mensaje(e));
    }
  }

  Future<void> _borrar(Rubro r) async {
    final ok = await confirmar(context, 'Borrar "${r.nombre}"',
        'Las prendas de este rubro no se borran: quedan "sin rubro" y las podés reasignar.');
    if (!ok) return;
    try {
      await Servicio.borrarRubro(r.id!);
      _cargar();
    } catch (e) {
      if (mounted) avisar(context, _mensaje(e));
    }
  }

  Future<void> _reordenar(int viejo, int nuevo) async {
    setState(() {
      if (nuevo > viejo) nuevo--;
      final r = _rubros.removeAt(viejo);
      _rubros.insert(nuevo, r);
    });
    try {
      await Servicio.ordenarRubros(_rubros);
    } catch (e) {
      if (mounted) avisar(context, _mensaje(e));
    }
  }

  String _mensaje(Object e) {
    final m = mensajeError(e);
    return m.contains('duplicate') || m.contains('unique')
        ? 'Ya existe un rubro con ese nombre'
        : m;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rubros')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevo,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo rubro'),
      ),
      body: Centrado(
        maxAncho: 640,
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: Marca.champagne))
            : _error != null
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Tarjeta(
                      child: Text(
                        'No se pudieron cargar los rubros:\n$_error\n\n'
                        '¿Corriste supabase/04_rubros.sql?',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Text(
                          'Son los tipos de productos que vendés. En la tienda '
                          'aparecen como secciones ("¿Qué estás buscando?"). '
                          'Arrastrá desde ☰ para cambiar el orden.',
                          style: TextStyle(color: Marca.gris),
                        ),
                      ),
                      Expanded(
                        child: _rubros.isEmpty
                            ? const SinDatos(
                                'No hay rubros. Tocá "Nuevo rubro".')
                            : ReorderableListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                buildDefaultDragHandles: false,
                                itemCount: _rubros.length,
                                onReorder: _reordenar,
                                itemBuilder: (context, i) {
                                  final r = _rubros[i];
                                  return Container(
                                    key: ValueKey(r.id),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: Marca.superficie,
                                      border: Border.all(color: Marca.borde),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: ListTile(
                                      leading: ReorderableDragStartListener(
                                        index: i,
                                        child: const Icon(Icons.drag_handle,
                                            color: Marca.gris),
                                      ),
                                      title: Text(r.nombre,
                                          style: Marca.titulo(24)),
                                      onTap: () => _renombrar(r),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: 'Renombrar',
                                            onPressed: () => _renombrar(r),
                                            icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 20),
                                          ),
                                          IconButton(
                                            tooltip: 'Borrar',
                                            onPressed: () => _borrar(r),
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                size: 20,
                                                color: Marca.gris),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}
