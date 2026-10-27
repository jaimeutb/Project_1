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
  static const azulNoche = Color(0xFF161A4A);
  static const azul10 = Color(0xFFEAEBF4);
  static const azul20 = Color(0xFFD6D7EA);

  static const fondo = Color(0xFFF4F6FB);
  static const borde = Color(0xFFE4E7F0);
  static const texto = Color(0xFF1B1E33);
  static const textoSecundario = Color(0xFF5D6178);
  static const ambar = Color(0xFFF2A900);
  static const ambar10 = Color(0xFFFFF6DD);
  static const error = Color(0xFFC62828);
  static const error10 = Color(0xFFFDECEA);
  static const exito = Color(0xFF187943);

  /// Degradado de marca para las cabeceras: del azul al verde de la UTB.
  static const degradado = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [azulOscuro, azul, verde],
    stops: [0, 0.55, 1],
  );

  /// Barra lateral: azul institucional muy oscuro.
  static const degradadoLateral = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [azulNoche, azulOscuro],
  );

  /// Sombra suave de las tarjetas.
  static const sombra = [
    BoxShadow(color: Color(0x0F1B1E33), blurRadius: 18, offset: Offset(0, 6)),
    BoxShadow(color: Color(0x081B1E33), blurRadius: 2, offset: Offset(0, 1)),
  ];
}

/// Fuente de la interfaz (assets/fuentes, licencia OFL).
const fuenteUtb = 'PlusJakartaSans';

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
    borderRadius: BorderRadius.all(Radius.circular(14)),
    borderSide: BorderSide(color: UtbColores.borde),
  );

  return ThemeData(
    useMaterial3: true,
    fontFamily: fuenteUtb,
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
        fontFamily: fuenteUtb,
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
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: UtbColores.verde, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: fuenteUtb, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: UtbColores.azul,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        side: const BorderSide(color: UtbColores.azul20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: fuenteUtb, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: const TextStyle(fontFamily: fuenteUtb, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: UtbColores.verde,
      foregroundColor: Colors.white,
      extendedTextStyle: TextStyle(fontFamily: fuenteUtb, fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: UtbColores.verde10,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerColor: UtbColores.borde,
  );
}

/// Tarjeta blanca con borde suave y sombra, la base visual de las pantallas.
class TarjetaUtb extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? colorBorde;
  final bool sombra;

  const TarjetaUtb({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.colorBorde,
    this.sombra = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorBorde ?? UtbColores.borde),
        boxShadow: sombra && color == null ? UtbColores.sombra : null,
      ),
      child: child,
    );
  }
}

/// Etiqueta pequeña de color (tipo de material, estado de la revisión...).
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;
  final Color fondo;
  final IconData? icono;

  const Etiqueta(this.texto, {super.key, required this.color, required this.fondo, this.icono});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(texto,
              style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Título de sección dentro de una página.
class TituloSeccion extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget? accion;

  const TituloSeccion(this.titulo, {super.key, this.subtitulo, this.accion});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 19, fontWeight: FontWeight.w800, color: UtbColores.texto)),
                if (subtitulo != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitulo!,
                      style: const TextStyle(color: UtbColores.textoSecundario, fontSize: 13.5)),
                ],
              ],
            ),
          ),
          if (accion != null) accion!,
        ],
      ),
    );
  }
}
