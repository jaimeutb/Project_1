import 'package:flutter/material.dart';

import '../theme/utb_theme.dart';
import 'logo_utb.dart';

/// Diseño común del inicio de sesión (RF-02) y del registro (RF-01): en
/// pantallas anchas, un panel institucional con los colores de la UTB a la
/// izquierda y el formulario a la derecha; en el celular, solo el formulario
/// con el logo arriba (RNF-03).
class PantallaAcceso extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget formulario;
  final bool mostrarVolver;

  const PantallaAcceso({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.formulario,
    this.mostrarVolver = false,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width >= 900;

    final contenido = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (mostrarVolver)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Volver'),
                  ),
                ),
              if (!ancho) ...[
                const Center(child: LogoUtb(altura: 64)),
                const SizedBox(height: 24),
              ],
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.w800, color: UtbColores.azulOscuro)),
              const SizedBox(height: 6),
              Text(subtitulo, style: const TextStyle(color: UtbColores.textoSecundario)),
              const SizedBox(height: 24),
              formulario,
              const SizedBox(height: 32),
              const Text(
                'Plataforma de Apoyo Académico · Proyecto de aula de Ingeniería de Software · UTB',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: UtbColores.textoSecundario),
              ),
            ],
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: ancho
          ? Row(
              children: [
                const Expanded(flex: 5, child: _PanelInstitucional()),
                Expanded(flex: 4, child: contenido),
              ],
            )
          : SafeArea(child: contenido),
    );
  }
}

class _PanelInstitucional extends StatelessWidget {
  const _PanelInstitucional();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: UtbColores.degradado),
      padding: const EdgeInsets.all(48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LogoUtb(altura: 84, sobreFondoOscuro: true),
          const Spacer(),
          const Text(
            'Plataforma de\nApoyo Académico',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Los parciales, quices y talleres de semestres anteriores, organizados por '
            'asignatura y explicados por un tutor con inteligencia artificial.',
            style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 32),
          for (final (icono, titulo, texto) in const [
            (Icons.auto_awesome, 'Tutor IA', 'Te explica cada material, te hace un quiz y resuelve tus dudas paso a paso.'),
            (Icons.folder_copy_outlined, 'Material por asignatura', 'Busca por semestre, asignatura o tema, sin distinguir tildes.'),
            (Icons.groups_outlined, 'Comunidad UTB', 'Sube material (también de forma anónima), valóralo y reporta errores.'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0x26FFFFFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icono, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        const SizedBox(height: 2),
                        Text(texto,
                            style: const TextStyle(color: Color(0xCCFFFFFF), height: 1.35)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          const Text('Universidad Tecnológica de Bolívar · Cartagena de Indias',
              style: TextStyle(color: Color(0xAAFFFFFF), fontSize: 12)),
        ],
      ),
    );
  }
}
