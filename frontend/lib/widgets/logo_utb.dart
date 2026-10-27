import 'package:flutter/material.dart';

/// Logosímbolo de la UTB. Según el manual de identidad, sobre fondo claro se usa
/// el logo «positivo en color» y sobre fondo oscuro el «invertido en color»
/// (símbolo a color y tipografía en blanco).
class LogoUtb extends StatelessWidget {
  final double altura;
  final bool sobreFondoOscuro;
  final bool soloSimbolo;

  const LogoUtb({
    super.key,
    this.altura = 48,
    this.sobreFondoOscuro = false,
    this.soloSimbolo = false,
  });

  @override
  Widget build(BuildContext context) {
    final archivo = soloSimbolo
        ? 'assets/utb/simbolo_utb.png'
        : sobreFondoOscuro
            ? 'assets/utb/logo_utb_blanco.png'
            : 'assets/utb/logo_utb.png';
    return Image.asset(
      archivo,
      height: altura,
      fit: BoxFit.contain,
      semanticLabel: 'Universidad Tecnológica de Bolívar',
      // En las pruebas de widgets los recursos pueden no cargarse: se deja el
      // espacio del logo para no alterar la distribución.
      errorBuilder: (_, __, ___) => SizedBox(height: altura, width: altura),
    );
  }
}
