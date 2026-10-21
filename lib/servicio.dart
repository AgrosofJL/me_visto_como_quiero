import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'prenda.dart';

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

  static Future<void> guardarPrenda(Prenda p) async {
    if (p.id == null) {
      await _db.from('prendas').insert(p.toMap());
    } else {
      await _db.from('prendas').update(p.toMap()).eq('id', p.id!);
    }
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
