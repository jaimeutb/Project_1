import 'package:flutter/material.dart';

/// Colores institucionales de la Universidad Tecnológica de Bolívar, tomados
/// del Manual de Identidad Corporativa de la UTB (sección «Colores»):
/// verde Pantone DS 277-2C y azul Pantone DS 184-1C, con sus degradados.
class UtbColores {
  static const verde = Color(0xFF187943);
  static const verdeOscuro = Color(0xFF0F5530);
  static const verde10 = Color(0xFFE8F1EC);
  static const verde20 = Color(0xFFD1E4D9);

  static const azul = Color(0xFF303990);
  static const azulOscuro = Color(0xFF1F2566);
  static const azul10 = Color(0xFFEAEBF4);
  static const azul20 = Color(0xFFD6D7EA);

  static const fondo = Color(0xFFF5F6FA);
  static const borde = Color(0xFFE2E4EE);
  static const texto = Color(0xFF1E2033);
  static const textoSecundario = Color(0xFF5D6178);
  static const ambar = Color(0xFFF2A900);
  static const error = Color(0xFFC62828);
  static const exito = Color(0xFF187943);

  /// Degradado de marca para las cabeceras: del azul al verde de la UTB.
  static const degradado = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [azulOscuro, azul, verde],
    stops: [0, 0.55, 1],
  );
}

ThemeData temaUtb() {
  final esquema = ColorScheme.fromSeed(
    seedColor: UtbColores.verde,
    primary: UtbColores.verde,
    onPrimary: Colors.white,
    primaryContainer: UtbColores.verde10,
    onPrimaryContainer: UtbColores.verdeOscuro,
    secondary: UtbColores.azul,
    onSecondary: Colors.white,
    secondaryContainer: UtbColores.azul10,
    onSecondaryContainer: UtbColores.azulOscuro,
    surface: Colors.white,
    onSurface: UtbColores.texto,
    error: UtbColores.error,
  );

  const bordeCampo = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: UtbColores.borde),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: UtbColores.fondo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: UtbColores.azulOscuro,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: UtbColores.borde,
      titleTextStyle: TextStyle(
        color: UtbColores.azulOscuro,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: bordeCampo,
      enabledBorder: bordeCampo,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: UtbColores.verde, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: UtbColores.azul,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        side: const BorderSide(color: UtbColores.azul20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: UtbColores.verde,
      foregroundColor: Colors.white,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerColor: UtbColores.borde,
  );
}

/// Tarjeta blanca con borde suave, la base visual de las pantallas.
class TarjetaUtb extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? colorBorde;

  const TarjetaUtb({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.colorBorde,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorBorde ?? UtbColores.borde),
      ),
      child: child,
    );
  }
}
