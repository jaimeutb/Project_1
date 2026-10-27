import 'package:flutter/material.dart';

import '../models/asignatura.dart';
import '../models/tutor_ia.dart';
import '../services/api_client.dart';
import '../services/tutor_ia_service.dart';
import '../theme/utb_theme.dart';
import '../widgets/quiz_interactivo.dart';

/// RF-18: simulacro de parcial. El estudiante elige una asignatura y la IA arma un
/// examen de práctica con los temas de sus parciales y talleres anteriores.
class SimulacroPagina extends StatefulWidget {
  final List<Asignatura> asignaturas;
  final String? token;
  final Asignatura? inicial;

  const SimulacroPagina({super.key, required this.asignaturas, required this.token, this.inicial});

  @override
  State<SimulacroPagina> createState() => _SimulacroPaginaState();
}

class _SimulacroPaginaState extends State<SimulacroPagina> {
  Asignatura? _asignatura;
  int _preguntas = 10;
  bool _cargando = false;
  String? _error;
  SimulacroIa? _simulacro;
  EstadoTutorIa? _estado;

  List<Asignatura> get _conMaterial =>
      widget.asignaturas.where((a) => a.totalMateriales > 0).toList();

  @override
  void initState() {
    super.initState();
    _asignatura = widget.inicial;
    TutorIaService(widget.token).estado().then((e) {
      if (mounted) setState(() => _estado = e);
    }).catchError((_) {});
  }

  Future<void> _generar() async {
    if (_asignatura == null) return;
    setState(() {
      _cargando = true;
      _error = null;
      _simulacro = null;
    });
    try {
      final s = await TutorIaService(widget.token).simulacro(_asignatura!.id, preguntas: _preguntas);
      if (mounted) setState(() => _simulacro = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _error = 'No fue posible conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noConfigurado = _estado != null && !_estado!.disponible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: UtbColores.degradado,
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Etiqueta('Simulacro IA',
                  color: Colors.white, fondo: Color(0x33FFFFFF), icono: Icons.auto_awesome),
              SizedBox(height: 12),
              Text('Simulacro de parcial',
                  style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              SizedBox(height: 6),
              Text(
                'La IA arma un examen de práctica con los temas que más se repiten en los '
                'parciales y talleres de la asignatura. Al terminar verás tu nota y qué repasar.',
                style: TextStyle(color: Color(0xE6FFFFFF), height: 1.45),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TarjetaUtb(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (noConfigurado)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'La IA no está configurada en este servidor: el administrador debe agregar '
                    'GEMINI_API_KEY en backend/.env.',
                    style: TextStyle(color: UtbColores.error),
                  ),
                ),
              DropdownButtonFormField<Asignatura>(
                // ignore: deprecated_member_use
                value: _conMaterial.contains(_asignatura) ? _asignatura : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Asignatura del simulacro'),
                items: [
                  for (final a in _conMaterial)
                    DropdownMenuItem(
                      value: a,
                      child: Text('${a.nombre} · ${a.totalMateriales} materiales',
                          overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (a) => setState(() => _asignatura = a),
              ),
              const SizedBox(height: 14),
              const Text('Número de preguntas',
                  style: TextStyle(fontWeight: FontWeight.w700, color: UtbColores.textoSecundario)),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 5, label: Text('5 · rápido')),
                  ButtonSegment(value: 10, label: Text('10')),
                  ButtonSegment(value: 15, label: Text('15 · completo')),
                ],
                selected: {_preguntas},
                onSelectionChanged: (s) => setState(() => _preguntas = s.first),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _cargando || _asignatura == null || noConfigurado ? null : _generar,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_simulacro == null ? 'Generar simulacro' : 'Generar otro simulacro'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!, style: const TextStyle(color: UtbColores.error)),
                ),
            ],
          ),
        ),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('La IA está leyendo los parciales anteriores y armando tu simulacro…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: UtbColores.textoSecundario)),
              ],
            ),
          ),
        if (_simulacro != null) ...[
          TituloSeccion(
            'Simulacro de ${_asignatura?.nombre ?? ''}',
            subtitulo: 'Basado en ${_simulacro!.materialesUsados} materiales de la asignatura. '
                'Generado con IA: puede contener errores.',
          ),
          QuizInteractivo(key: ObjectKey(_simulacro), preguntas: _simulacro!.preguntas),
        ],
      ],
    );
  }
}
