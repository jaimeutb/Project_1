import 'package:flutter/material.dart';

import '../models/tutor_ia.dart';
import '../theme/utb_theme.dart';

/// Quiz de opción múltiple con retroalimentación inmediata (RF-15 y RF-18). Al
/// responder cada pregunta muestra si acertó y por qué; al terminar, los temas
/// que conviene repasar según las preguntas falladas.
class QuizInteractivo extends StatefulWidget {
  final List<PreguntaPractica> preguntas;

  const QuizInteractivo({super.key, required this.preguntas});

  @override
  State<QuizInteractivo> createState() => _QuizInteractivoState();
}

class _QuizInteractivoState extends State<QuizInteractivo> {
  // Respuesta elegida por el estudiante en cada pregunta (por posición).
  final Map<int, int> _respuestas = {};

  @override
  Widget build(BuildContext context) {
    final preguntas = widget.preguntas;
    final total = preguntas.length;
    final correctas =
        _respuestas.entries.where((r) => preguntas[r.key].correcta == r.value).length;
    final terminado = _respuestas.length == total;
    final temasFallados = {
      for (final r in _respuestas.entries)
        if (preguntas[r.key].correcta != r.value && preguntas[r.key].tema.isNotEmpty)
          preguntas[r.key].tema,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Marcador(respondidas: _respuestas.length, correctas: correctas, total: total),
        const SizedBox(height: 12),
        for (final (i, pregunta) in preguntas.indexed)
          _TarjetaPregunta(
            numero: i + 1,
            pregunta: pregunta,
            elegida: _respuestas[i],
            onElegir: (opcion) => setState(() => _respuestas[i] = opcion),
          ),
        if (terminado) _Resultado(correctas: correctas, total: total, temas: temasFallados),
      ],
    );
  }
}

class _Marcador extends StatelessWidget {
  final int respondidas;
  final int correctas;
  final int total;
  const _Marcador({required this.respondidas, required this.correctas, required this.total});

  @override
  Widget build(BuildContext context) {
    return TarjetaUtb(
      padding: const EdgeInsets.all(14),
      color: UtbColores.azul10,
      colorBorde: UtbColores.azul20,
      child: Row(
        children: [
          const Icon(Icons.emoji_events_outlined, color: UtbColores.azul),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Respondidas: $respondidas de $total · Correctas: $correctas',
              style: const TextStyle(fontWeight: FontWeight.w700, color: UtbColores.azulOscuro),
            ),
          ),
          SizedBox(
            width: 72,
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : respondidas / total,
              minHeight: 7,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Resultado extends StatelessWidget {
  final int correctas;
  final int total;
  final Set<String> temas;
  const _Resultado({required this.correctas, required this.total, required this.temas});

  @override
  Widget build(BuildContext context) {
    final nota = total == 0 ? 0.0 : correctas / total * 5;
    final (titulo, color, fondo) = correctas == total
        ? ('¡Excelente! Dominas estos temas.', UtbColores.verdeOscuro, UtbColores.verde10)
        : nota >= 3
            ? ('Vas bien: repasa lo que fallaste.', UtbColores.azulOscuro, UtbColores.azul10)
            : ('Te conviene repasar antes del examen.', const Color(0xFF8A5A00), UtbColores.ambar10);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(nota.toStringAsFixed(1),
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: color)),
              Text(' / 5,0', style: TextStyle(color: color, fontWeight: FontWeight.w600)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(titulo, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
              ),
            ],
          ),
          if (temas.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Temas para repasar:',
                style: TextStyle(fontWeight: FontWeight.w700, color: color, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in temas)
                  Etiqueta(t, color: color, fondo: Colors.white, icono: Icons.bookmark_outline),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _TarjetaPregunta extends StatelessWidget {
  final int numero;
  final PreguntaPractica pregunta;
  final int? elegida;
  final ValueChanged<int> onElegir;

  const _TarjetaPregunta({
    required this.numero,
    required this.pregunta,
    required this.elegida,
    required this.onElegir,
  });

  @override
  Widget build(BuildContext context) {
    final respondida = elegida != null;
    final acerto = elegida == pregunta.correcta;
    const letras = ['A', 'B', 'C', 'D', 'E', 'F'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TarjetaUtb(
        padding: const EdgeInsets.all(16),
        sombra: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('Pregunta $numero',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, color: UtbColores.azul, fontSize: 13)),
                if (pregunta.tema.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('· ${pregunta.tema}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: UtbColores.textoSecundario, fontSize: 12.5)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(pregunta.enunciado,
                style: const TextStyle(fontWeight: FontWeight.w600, height: 1.4)),
            const SizedBox(height: 12),
            for (final (i, opcion) in pregunta.opciones.indexed)
              _Opcion(
                letra: i < letras.length ? letras[i] : '${i + 1}',
                texto: opcion,
                estado: !respondida
                    ? _EstadoOpcion.normal
                    : i == pregunta.correcta
                        ? _EstadoOpcion.correcta
                        : i == elegida
                            ? _EstadoOpcion.incorrecta
                            : _EstadoOpcion.inactiva,
                onTap: respondida ? null : () => onElegir(i),
              ),
            if (respondida)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: acerto ? UtbColores.verde10 : UtbColores.error10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(acerto ? '¡Correcto!' : 'Incorrecto',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: acerto ? UtbColores.verdeOscuro : UtbColores.error)),
                    const SizedBox(height: 4),
                    SelectableText(pregunta.explicacion, style: const TextStyle(height: 1.45)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum _EstadoOpcion { normal, correcta, incorrecta, inactiva }

class _Opcion extends StatelessWidget {
  final String letra;
  final String texto;
  final _EstadoOpcion estado;
  final VoidCallback? onTap;

  const _Opcion({required this.letra, required this.texto, required this.estado, this.onTap});

  @override
  Widget build(BuildContext context) {
    final (fondo, borde, icono) = switch (estado) {
      _EstadoOpcion.correcta => (UtbColores.verde10, UtbColores.verde, Icons.check_circle),
      _EstadoOpcion.incorrecta => (UtbColores.error10, UtbColores.error, Icons.cancel),
      _ => (Colors.white, UtbColores.borde, null),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: fondo,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borde),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 13,
                  backgroundColor:
                      estado == _EstadoOpcion.inactiva ? UtbColores.fondo : UtbColores.azul10,
                  child: Text(letra,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800, color: UtbColores.azul)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    texto,
                    style: TextStyle(
                      color: estado == _EstadoOpcion.inactiva
                          ? UtbColores.textoSecundario
                          : UtbColores.texto,
                    ),
                  ),
                ),
                if (icono != null) Icon(icono, color: borde, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
