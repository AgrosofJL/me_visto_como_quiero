import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'config.dart';

/// Paleta de la marca: negro profundo, marfil y un toque champagne.
class Marca {
  static const negro = Color(0xFF0B0B0B);
  static const superficie = Color(0xFF151515);
  static const superficieAlta = Color(0xFF1E1E1E);
  static const borde = Color(0x33FFFFFF);
  static const marfil = Color(0xFFF4EFE8);
  static const gris = Color(0xFFA8A29B);
  static const champagne = Color(0xFFD4B483);
  static const champagneOscuro = Color(0xFFB8955F);
  static const whatsapp = Color(0xFF25D366);

  static TextStyle titulo(double size,
          {FontWeight peso = FontWeight.w500,
          Color color = marfil,
          FontStyle estilo = FontStyle.normal}) =>
      GoogleFonts.cormorantGaramond(
        fontSize: size,
        fontWeight: peso,
        color: color,
        fontStyle: estilo,
        height: 1.05,
      );

  static TextStyle etiqueta({Color color = gris, double size = 11}) =>
      GoogleFonts.jost(
        fontSize: size,
        letterSpacing: 2.4,
        fontWeight: FontWeight.w500,
        color: color,
      );
}

ThemeData temaTienda() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Marca.champagne,
      onPrimary: Marca.negro,
      secondary: Marca.marfil,
      onSecondary: Marca.negro,
      surface: Marca.superficie,
      onSurface: Marca.marfil,
      error: Color(0xFFE57373),
    ),
    scaffoldBackgroundColor: Marca.negro,
  );

  final texto = GoogleFonts.jostTextTheme(base.textTheme).apply(
    bodyColor: Marca.marfil,
    displayColor: Marca.marfil,
  );

  const forma = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(2)));

  return base.copyWith(
    textTheme: texto,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      foregroundColor: Marca.marfil,
      titleTextStyle: Marca.titulo(24),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Marca.champagne,
        foregroundColor: Marca.negro,
        shape: forma,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        textStyle: GoogleFonts.jost(
            fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.6),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Marca.marfil,
        side: const BorderSide(color: Marca.marfil, width: 1),
        shape: forma,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        textStyle: GoogleFonts.jost(
            fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1.6),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Marca.champagne),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.transparent,
      selectedColor: Marca.marfil,
      side: const BorderSide(color: Marca.borde),
      shape: const StadiumBorder(),
      labelStyle: GoogleFonts.jost(fontSize: 13, color: Marca.marfil),
      secondaryLabelStyle: GoogleFonts.jost(fontSize: 13, color: Marca.negro),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.black.withValues(alpha: .35),
      labelStyle: const TextStyle(color: Marca.gris),
      hintStyle: const TextStyle(color: Marca.gris),
      border: const OutlineInputBorder(
          borderSide: BorderSide(color: Marca.borde),
          borderRadius: BorderRadius.all(Radius.circular(2))),
      enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Marca.borde),
          borderRadius: BorderRadius.all(Radius.circular(2))),
      focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Marca.champagne),
          borderRadius: BorderRadius.all(Radius.circular(2))),
    ),
    dividerTheme: const DividerThemeData(color: Marca.borde, space: 1),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Marca.marfil,
      contentTextStyle: TextStyle(color: Marca.negro),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Marca.superficie,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Marca.superficie),
  );
}

/// Fondo negro con el logo de la tienda translúcido, fijo detrás del contenido.
class FondoMarca extends StatelessWidget {
  const FondoMarca({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Marca.negro),
        IgnorePointer(
          child: Center(
            child: FractionallySizedBox(
              widthFactor: .9,
              heightFactor: .9,
              child: Opacity(
                opacity: Config.opacidadLogoFondo,
                child: Image.asset('assets/logo_blanco.png',
                    fit: BoxFit.contain),
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// Panel tipo "vidrio esmerilado": deja ver el logo detrás pero desenfocado,
/// así el texto se lee bien.
class PanelVidrio extends StatelessWidget {
  const PanelVidrio({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.opacidad = .55,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double opacidad;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: opacidad),
            border: Border.all(color: Marca.borde),
            borderRadius: BorderRadius.circular(4),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Ancho máximo del contenido en pantallas grandes, centrado.
class Centrado extends StatelessWidget {
  const Centrado({super.key, required this.child, this.maxAncho = 1200});
  final Widget child;
  final double maxAncho;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxAncho),
          child: child,
        ),
      );
}
