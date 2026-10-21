import 'package:url_launcher/url_launcher.dart';

/// Configuración general de la tienda. Todo lo editable "a mano" está acá.
///
/// La clave "anon" de Supabase es pública por diseño (va dentro de la app).
/// La seguridad real está en las reglas (RLS) de supabase/esquema.sql.
class Config {
  static const supabaseUrl = 'https://onjiddcqsldwssuiriqq.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9uamlkZGNxc2xkd3NzdWlyaXFxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2MjE0MDQsImV4cCI6MjEwODE5NzQwNH0.i0eDHnaPTqjmRKabrQT5fLhTa9_d18uc0w9exkSpf6Q';

  // ---------------- Marca ----------------
  static const nombreTienda = 'Any.G';
  static const eslogan = 'Me visto como quiero';
  static const subtitulo = 'Tienda de ropa · Chimpay, Río Negro';

  /// Opacidad del logo de fondo (0 = invisible, 1 = completo).
  static const opacidadLogoFondo = 0.6;

  // ---------------- Contacto ----------------
  /// WhatsApp: código de país + área + número, sin "+", espacios ni guiones.
  static const whatsapp = '5492984616568';
  static const whatsappVisible = '2984-616568';
  static const direccion = 'Chimpay, Río Negro';

  /// Ubicación del local (Google Maps).
  static const latitud = -39.163180;
  static const longitud = -66.154974;
  static const linkMapa =
      'https://www.google.com/maps/search/?api=1&query=$latitud,$longitud';
  static const horario = 'Lunes a sábado de 9 a 12:30 y de 17 a 21 h';

  // ---------------- Pedidos ----------------
  /// Horarios que el cliente puede elegir para retirar / recibir.
  static const franjasHorarias = [
    '9:00 a 10:00',
    '10:00 a 11:00',
    '11:00 a 12:30',
    '17:00 a 18:00',
    '18:00 a 19:00',
    '19:00 a 20:00',
    '20:00 a 21:00',
  ];

  /// Días de la semana en que NO se entregan pedidos (7 = domingo).
  static const diasCerrado = [DateTime.sunday];

  /// Hasta cuántos días adelante se puede elegir fecha.
  static const diasMaxReserva = 21;

  static const formasDePago = ['Efectivo', 'Transferencia'];

  /// Alias/CBU para transferencias. Dejalo vacío ('') para no mostrarlo.
  static const aliasTransferencia = '';

  /// Se ofrece envío a domicilio además de retiro en el local.
  static const ofreceEnvio = true;

  /// Nombre del "bucket" de Supabase Storage donde se guardan las fotos.
  static const bucketFotos = 'fotos';
}

/// Abre Google Maps (app o web) con la ubicación del local.
Future<void> abrirMapa() => launchUrl(
      Uri.parse(Config.linkMapa),
      mode: LaunchMode.externalApplication,
    );
