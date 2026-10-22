import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'oferta.dart';
import 'prenda.dart';
import 'venta.dart';

/// Todo lo que habla con Supabase está acá.
class Servicio {
  static SupabaseClient get _db => Supabase.instance.client;

  // ---------- Catálogo ----------

  /// Prendas visibles. Un admin logueado también ve las "no disponibles".
  static Future<List<Prenda>> listarPrendas() async {
    final filas = await _db
        .from('prendas')
        .select()
        .order('created_at', ascending: false);
    return filas.map(Prenda.fromMap).toList();
  }

  /// Catálogo con las ofertas vigentes ya aplicadas a cada prenda.
  static Future<List<Prenda>> catalogo() async {
    final prendas = await listarPrendas();
    try {
      return aplicarOfertas(prendas, await listarOfertas());
    } catch (_) {
      return prendas; // Si todavía no existe la tabla de ofertas
    }
  }

  // ---------- Ofertas ----------

  /// Visitantes: solo vigentes. Admin: todas.
  static Future<List<Oferta>> listarOfertas() async {
    final filas = await _db
        .from('ofertas')
        .select('*, oferta_prendas(*)')
        .order('created_at', ascending: false);
    return filas.map(Oferta.fromMap).toList();
  }

  /// Crea o actualiza la oferta y reemplaza su lista de prendas.
  static Future<void> guardarOferta(Oferta o) async {
    String id;
    if (o.id == null) {
      final fila =
          await _db.from('ofertas').insert(o.toMap()).select('id').single();
      id = fila['id'] as String;
    } else {
      id = o.id!;
      await _db.from('ofertas').update(o.toMap()).eq('id', id);
      await _db.from('oferta_prendas').delete().eq('oferta_id', id);
    }
    if (o.prendas.isNotEmpty) {
      await _db.from('oferta_prendas').insert([
        for (final e in o.prendas.entries)
          {'oferta_id': id, 'prenda_id': e.key, 'precio_especial': e.value},
      ]);
    }
  }

  static Future<void> activarOferta(String id, bool activa) async {
    await _db.from('ofertas').update({'activa': activa}).eq('id', id);
  }

  static Future<void> borrarOferta(String id) async {
    await _db.from('ofertas').delete().eq('id', id);
  }

  /// Guarda la prenda y devuelve su id.
  static Future<String> guardarPrenda(Prenda p) async {
    if (p.id == null) {
      final fila =
          await _db.from('prendas').insert(p.toMap()).select('id').single();
      return fila['id'] as String;
    }
    await _db.from('prendas').update(p.toMap()).eq('id', p.id!);
    return p.id!;
  }

  // ---------- Costos (solo admin) ----------

  static Future<Map<String, double>> listarCostos() async {
    final filas = await _db.from('costos').select();
    return {
      for (final f in filas)
        f['prenda_id'] as String: (f['costo'] as num).toDouble(),
    };
  }

  static Future<void> guardarCosto(String prendaId, double costo) async {
    await _db.from('costos').upsert({'prenda_id': prendaId, 'costo': costo});
  }

  // ---------- Ventas (solo admin) ----------

  /// Registra la venta y descuenta stock. Si no alcanza el stock, tira error.
  static Future<String> registrarVenta({
    required List<ItemVenta> items,
    required String formaPago,
    required String canal,
    String cliente = '',
    String nota = '',
  }) async {
    final id = await _db.rpc('registrar_venta', params: {
      'p_items': items.map((i) => i.toRpc()).toList(),
      'p_forma_pago': formaPago,
      'p_cliente': cliente,
      'p_nota': nota,
      'p_canal': canal,
    });
    return id as String;
  }

  static Future<void> anularVenta(String id) async {
    await _db.rpc('anular_venta', params: {'p_venta': id});
  }

  /// Ventas entre [desde] (incluido) y [hasta] (excluido), con sus ítems.
  static Future<List<Venta>> listarVentas(DateTime desde, DateTime hasta) async {
    final filas = await _db
        .from('ventas')
        .select('*, venta_items(*)')
        .gte('fecha', desde.toUtc().toIso8601String())
        .lt('fecha', hasta.toUtc().toIso8601String())
        .order('fecha', ascending: false);
    return filas.map(Venta.fromMap).toList();
  }

  static Future<void> borrarPrenda(Prenda p) async {
    await _db.from('prendas').delete().eq('id', p.id!);
    if (p.imagenPath != null) await borrarFoto(p.imagenPath!);
  }

  // ---------- Fotos ----------

  /// Sube una foto y devuelve (url pública, ruta interna).
  static Future<(String, String)> subirFoto(
      Uint8List bytes, String nombreArchivo, String? tipo) async {
    final ext = nombreArchivo.contains('.')
        ? nombreArchivo.split('.').last.toLowerCase()
        : 'jpg';
    final ruta = 'prendas/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from(Config.bucketFotos).uploadBinary(
          ruta,
          bytes,
          fileOptions: FileOptions(contentType: tipo ?? 'image/$ext'),
        );
    final url = _db.storage.from(Config.bucketFotos).getPublicUrl(ruta);
    return (url, ruta);
  }

  static Future<void> borrarFoto(String ruta) async {
    try {
      await _db.storage.from(Config.bucketFotos).remove([ruta]);
    } catch (_) {
      // Si la foto ya no existe no pasa nada.
    }
  }

  // ---------- Login de administrador ----------

  static bool get haySesion => _db.auth.currentSession != null;

  static String? get emailActual => _db.auth.currentUser?.email;

  static Future<void> entrar(String email, String clave) async {
    await _db.auth.signInWithPassword(email: email.trim(), password: clave);
  }

  static Future<void> salir() => _db.auth.signOut();

  /// Pregunta a la base si el usuario logueado está en la tabla `admins`.
  static Future<bool> esAdmin() async {
    if (!haySesion) return false;
    final r = await _db.rpc('es_admin');
    return r == true;
  }
}
