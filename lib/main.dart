import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'carrito.dart';
import 'catalogo.dart';
import 'config.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Config.supabaseUrl,
    publishableKey: Config.supabaseAnonKey,
  );
  await carrito.cargar(); // recupera el pedido que el cliente dejó armado
  runApp(const TiendaApp());
}

class TiendaApp extends StatelessWidget {
  const TiendaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${Config.nombreTienda} · ${Config.eslogan}',
      debugShowCheckedModeBanner: false,
      theme: temaTienda(),
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const CatalogoPage(),
    );
  }
}
