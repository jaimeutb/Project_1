import 'package:flutter/material.dart';

import '../models/tutor_ia.dart';
import '../services/api_client.dart';
import '../services/tutor_ia_service.dart';
import '../theme/utb_theme.dart';
import 'quiz_interactivo.dart';

enum SeccionTutor { explicacion, practica, preguntas }

/// Tutor IA de un material (RF-14, RF-15, RF-16): explica el material, genera
/// preguntas de práctica y responde dudas. Cada sección conserva su resultado
/// al cambiar de pestaña.
class TutorIaPanel extends StatefulWidget {
  final int materialId;
  final String? token;

  const TutorIaPanel({super.key, required this.materialId, required this.token});

  @override
  State<TutorIaPanel> createState() => _TutorIaPanelState();
}

class _TutorIaPanelState extends State<TutorIaPanel> {
  SeccionTutor _seccion = SeccionTutor.explicacion;
  EstadoTutorIa? _estado;
  String? _errorEstado;

  TutorIaService get _service => TutorIaService(widget.token);

  @override
  void initState() {
    super.initState();
    _consultarEstado();
  }

  Future<void> _consultarEstado() async {
    try {
      final estado = await _service.estado();
      if (mounted) setState(() => _estado = estado);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorEstado = e.mensaje);
    } catch (_) {
      if (mounted) setState(() => _errorEstado = 'No fue posible conectar con el servidor.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UtbColores.azul20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _CabeceraTutor(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _contenido(),
          ),
          const _AvisoIa(),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_errorEstado != null) return _MensajeError(_errorEstado!);
    if (_estado == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_estado!.disponible) {
      return const _MensajeInfo(
        icono: Icons.key_off_outlined,
        titulo: 'El Tutor IA no está configurado en este servidor',
        texto: 'El administrador debe agregar la clave gratuita GEMINI_API_KEY (de Google AI '
            'Studio) en backend/.env y reiniciar el servidor. El resto de la plataforma funciona normalmente.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En el celular las pestañas van sin ícono, para que el nombre quepa en una línea.
        LayoutBuilder(builder: (context, constraints) {
          final conIconos = constraints.maxWidth >= 420;
          ButtonSegment<SeccionTutor> pestana(SeccionTutor valor, IconData icono, String nombre) =>
              ButtonSegment(
                value: valor,
                icon: conIconos ? Icon(icono) : null,
                label: Text(nombre, maxLines: 1, softWrap: false),
              );
          return SegmentedButton<SeccionTutor>(
            showSelectedIcon: false,
            segments: [
              pestana(SeccionTutor.explicacion, Icons.lightbulb_outline, 'Explicación'),
              pestana(SeccionTutor.practica, Icons.quiz_outlined, 'Practicar'),
              pestana(SeccionTutor.preguntas, Icons.forum_outlined, 'Preguntar'),
            ],
            selected: {_seccion},
            onSelectionChanged: (s) => setState(() => _seccion = s.first),
          );
        }),
        const SizedBox(height: 16),
        // Las secciones ocultas conservan su estado (la explicación, el quiz o la
        // conversación) y no ocupan espacio.
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Visibility(
              visible: _seccion == SeccionTutor.explicacion,
              maintainState: true,
              child: _SeccionExplicacion(materialId: widget.materialId, service: _service),
            ),
            Visibility(
              visible: _seccion == SeccionTutor.practica,
              maintainState: true,
              child: _SeccionPractica(materialId: widget.materialId, service: _service),
            ),
            Visibility(
              visible: _seccion == SeccionTutor.preguntas,
              maintainState: true,
              child: _SeccionPreguntas(materialId: widget.materialId, service: _service),
            ),
          ],
        ),
      ],
    );
  }
}

class _CabeceraTutor extends StatelessWidget {
  const _CabeceraTutor();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: const BoxDecoration(gradient: UtbColores.degradado),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Color(0x33FFFFFF),
            child: Icon(Icons.auto_awesome, color: Colors.white),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tutor IA',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Tu monitor de estudio con inteligencia artificial',
                    style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Transparencia: las respuestas son generadas por IA y pueden tener errores.
class _AvisoIa extends StatelessWidget {
  const _AvisoIa();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: UtbColores.azul10,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: UtbColores.azul),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Generado con IA: puede contener errores. Compáralo con tus apuntes y '
              'con lo que explicó tu profesor.',
              style: TextStyle(fontSize: 12, color: UtbColores.azulOscuro),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- RF-14

class _SeccionExplicacion extends StatefulWidget {
  final int materialId;
  final TutorIaService service;
  const _SeccionExplicacion({required this.materialId, required this.service});

  @override
  State<_SeccionExplicacion> createState() => _SeccionExplicacionState();
}

class _SeccionExplicacionState extends State<_SeccionExplicacion> {
  ExplicacionIa? _explicacion;
  bool _cargando = false;
  String? _error;

  Future<void> _generar({bool nueva = false}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final explicacion = await widget.service.explicar(widget.materialId, nueva: nueva);
      if (mounted) setState(() => _explicacion = explicacion);
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
    if (_cargando) {
      return const _Cargando('El Tutor IA está leyendo el material. Puede tardar hasta un minuto…');
    }
    final e = _explicacion;
    if (e == null) {
      return _Inicio(
        icono: Icons.lightbulb_outline,
        texto: 'Obtén un resumen del material, los temas que evalúa explicados de forma '
            'sencilla y sus ejercicios clave con pista y solución paso a paso.',
        boton: 'Explicar este material',
        error: _error,
        onPressed: _generar,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!e.leyoArchivo) const _AvisoSinArchivo(),
        const _Subtitulo(Icons.summarize_outlined, 'En resumen'),
        SelectableText(e.resumen, style: const TextStyle(height: 1.45)),
        if (e.temas.isNotEmpty) ...[
          const _Subtitulo(Icons.topic_outlined, 'Temas que evalúa'),
          for (final tema in e.temas) _TarjetaTema(tema),
        ],
        if (e.ejercicios.isNotEmpty) ...[
          const _Subtitulo(Icons.edit_note, 'Ejercicios clave'),
          for (final (i, ejercicio) in e.ejercicios.indexed) _TarjetaEjercicio(i + 1, ejercicio),
        ],
        if (e.consejos.isNotEmpty) ...[
          const _Subtitulo(Icons.tips_and_updates_outlined, 'Consejos para el examen'),
          for (final consejo in e.consejos)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle, size: 16, color: UtbColores.verde),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: SelectableText(consejo)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _generar(nueva: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Explicar de otra forma'),
          ),
        ),
      ],
    );
  }
}

class _TarjetaTema extends StatelessWidget {
  final TemaIa tema;
  const _TarjetaTema(this.tema);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TarjetaUtb(
        padding: const EdgeInsets.all(14),
        color: UtbColores.verde10,
        colorBorde: UtbColores.verde20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tema.nombre,
                style: const TextStyle(fontWeight: FontWeight.w700, color: UtbColores.verdeOscuro)),
            const SizedBox(height: 6),
            SelectableText(tema.explicacion, style: const TextStyle(height: 1.45)),
            if (tema.ejemplo.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText('Ejemplo: ${tema.ejemplo}',
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Ejercicio con la pista y la solución ocultas, para que el estudiante
/// intente resolverlo antes de ver la respuesta.
class _TarjetaEjercicio extends StatefulWidget {
  final int numero;
  final EjercicioIa ejercicio;
  const _TarjetaEjercicio(this.numero, this.ejercicio);

  @override
  State<_TarjetaEjercicio> createState() => _TarjetaEjercicioState();
}

class _TarjetaEjercicioState extends State<_TarjetaEjercicio> {
  bool _verPista = false;
  bool _verSolucion = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.ejercicio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TarjetaUtb(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ejercicio ${widget.numero}',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: UtbColores.azul, fontSize: 13)),
            const SizedBox(height: 4),
            SelectableText(e.enunciado, style: const TextStyle(height: 1.45)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilterChip(
                avatar: const Icon(Icons.tips_and_updates_outlined, size: 18),
                label: Text(_verPista ? 'Ocultar pista' : 'Ver pista'),
                selected: _verPista,
                showCheckmark: false,
                onSelected: (v) => setState(() => _verPista = v),
              ),
              FilterChip(
                avatar: const Icon(Icons.task_alt, size: 18),
                label: Text(_verSolucion ? 'Ocultar solución' : 'Ver solución'),
                selected: _verSolucion,
                showCheckmark: false,
                onSelected: (v) => setState(() => _verSolucion = v),
              ),
            ]),
            if (_verPista) _Revelado('Pista', e.pista, UtbColores.azul10),
            if (_verSolucion) _Revelado('Solución paso a paso', e.solucion, UtbColores.verde10),
          ],
        ),
      ),
    );
  }
}

class _Revelado extends StatelessWidget {
  final String titulo;
  final String texto;
  final Color color;
  const _Revelado(this.titulo, this.texto, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          SelectableText(texto, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- RF-15

class _SeccionPractica extends StatefulWidget {
  final int materialId;
  final TutorIaService service;
  const _SeccionPractica({required this.materialId, required this.service});

  @override
  State<_SeccionPractica> createState() => _SeccionPracticaState();
}

class _SeccionPracticaState extends State<_SeccionPractica> {
  PracticaIa? _practica;
  bool _cargando = false;
  String? _error;

  Future<void> _generar({bool nueva = false}) async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final practica = await widget.service.practicar(widget.materialId, nueva: nueva);
      if (mounted) setState(() => _practica = practica);
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
    if (_cargando) {
      return const _Cargando('El Tutor IA está preparando tus preguntas…');
    }
    final practica = _practica;
    if (practica == null) {
      return _Inicio(
        icono: Icons.quiz_outlined,
        texto: 'Pon a prueba lo que sabes con 5 preguntas de opción múltiple sobre los '
            'temas de este material. Al responder verás si acertaste y por qué.',
        boton: 'Generar quiz',
        error: _error,
        onPressed: _generar,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!practica.leyoArchivo) const _AvisoSinArchivo(),
        // La clave reinicia las respuestas cuando llegan preguntas nuevas.
        QuizInteractivo(key: ObjectKey(practica), preguntas: practica.preguntas),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _generar(nueva: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Nuevas preguntas'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- RF-16

const sugerenciasTutor = [
  '¿Qué temas debo repasar para este parcial?',
  'Explícame el primer ejercicio paso a paso',
  'Dame un ejercicio parecido para practicar',
];

class _SeccionPreguntas extends StatefulWidget {
  final int materialId;
  final TutorIaService service;
  const _SeccionPreguntas({required this.materialId, required this.service});

  @override
  State<_SeccionPreguntas> createState() => _SeccionPreguntasState();
}

class _SeccionPreguntasState extends State<_SeccionPreguntas> {
  final _preguntaCtrl = TextEditingController();
  final List<TurnoChat> _conversacion = [];
  bool _esperando = false;
  String? _error;

  @override
  void dispose() {
    _preguntaCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar([String? texto]) async {
    final pregunta = (texto ?? _preguntaCtrl.text).trim();
    if (pregunta.isEmpty || _esperando) return;
    final historial = List<TurnoChat>.of(_conversacion);
    setState(() {
      _conversacion.add(TurnoChat(esDelTutor: false, texto: pregunta));
      _preguntaCtrl.clear();
      _esperando = true;
      _error = null;
    });
    try {
      final respuesta = await widget.service.preguntar(widget.materialId, historial, pregunta);
      if (mounted) setState(() => _conversacion.add(TurnoChat(esDelTutor: true, texto: respuesta)));
    } on ApiException catch (e) {
      // La pregunta sin respuesta se quita para que el historial siga alternando.
      if (mounted) {
        setState(() {
          _conversacion.removeLast();
          _preguntaCtrl.text = pregunta;
          _error = e.mensaje;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _conversacion.removeLast();
          _preguntaCtrl.text = pregunta;
          _error = 'No fue posible conectar con el servidor.';
        });
      }
    } finally {
      if (mounted) setState(() => _esperando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_conversacion.isEmpty) ...[
          const Text(
            'Pregúntale al tutor lo que no entiendas de este material: un ejercicio, un '
            'concepto o cómo prepararte. Prueba con una de estas:',
            style: TextStyle(color: UtbColores.textoSecundario, height: 1.4),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in sugerenciasTutor)
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 16, color: UtbColores.azul),
                  label: Text(s),
                  onPressed: () => _enviar(s),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        for (final turno in _conversacion) _Burbuja(turno),
        if (_esperando) const _Burbuja(TurnoChat(esDelTutor: true, texto: ''), escribiendo: true),
        if (_error != null) _MensajeError(_error!),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _preguntaCtrl,
                minLines: 1,
                maxLines: 4,
                maxLength: 2000,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Escribe tu pregunta…',
                  counterText: '',
                  isDense: true,
                ),
                onSubmitted: (_) => _enviar(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Enviar pregunta',
              onPressed: _esperando ? null : _enviar,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ],
    );
  }
}

class _Burbuja extends StatelessWidget {
  final TurnoChat turno;
  final bool escribiendo;
  const _Burbuja(this.turno, {this.escribiendo = false});

  @override
  Widget build(BuildContext context) {
    final delTutor = turno.esDelTutor;
    final burbuja = Container(
      constraints: const BoxConstraints(maxWidth: 520),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: delTutor ? UtbColores.fondo : UtbColores.azul,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(delTutor ? 4 : 14),
          bottomRight: Radius.circular(delTutor ? 14 : 4),
        ),
      ),
      child: escribiendo
          ? const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('El tutor está escribiendo…',
                    style: TextStyle(color: UtbColores.textoSecundario)),
              ],
            )
          : SelectableText(
              turno.texto,
              style: TextStyle(color: delTutor ? UtbColores.texto : Colors.white, height: 1.45),
            ),
    );
    return Row(
      mainAxisAlignment: delTutor ? MainAxisAlignment.start : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (delTutor)
          const Padding(
            padding: EdgeInsets.only(right: 8, top: 2),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: UtbColores.verde10,
              child: Icon(Icons.auto_awesome, size: 16, color: UtbColores.verde),
            ),
          ),
        Flexible(child: burbuja),
      ],
    );
  }
}

// ---------------------------------------------------------------- comunes

class _Inicio extends StatelessWidget {
  final IconData icono;
  final String texto;
  final String boton;
  final String? error;
  final VoidCallback onPressed;

  const _Inicio({
    required this.icono,
    required this.texto,
    required this.boton,
    required this.error,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icono, color: UtbColores.verde, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(texto,
                  style: const TextStyle(color: UtbColores.textoSecundario, height: 1.45)),
            ),
          ],
        ),
        if (error != null) _MensajeError(error!),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.auto_awesome),
          label: Text(boton),
        ),
      ],
    );
  }
}

class _Cargando extends StatelessWidget {
  final String texto;
  const _Cargando(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(texto,
              textAlign: TextAlign.center,
              style: const TextStyle(color: UtbColores.textoSecundario)),
        ],
      ),
    );
  }
}

class _Subtitulo extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Subtitulo(this.icono, this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          Icon(icono, size: 20, color: UtbColores.azul),
          const SizedBox(width: 8),
          Text(texto,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: UtbColores.azulOscuro)),
        ],
      ),
    );
  }
}

class _AvisoSinArchivo extends StatelessWidget {
  const _AvisoSinArchivo();

  @override
  Widget build(BuildContext context) {
    return const _MensajeInfo(
      icono: Icons.description_outlined,
      titulo: 'La IA no pudo leer el archivo',
      texto: 'Este material es un Word, un ZIP o un archivo muy grande, así que el tutor '
          'trabajó solo con su título y su descripción.',
    );
  }
}

class _MensajeInfo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  const _MensajeInfo({required this.icono, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5DFA0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: const Color(0xFF8A6100)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(texto, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MensajeError extends StatelessWidget {
  final String mensaje;
  const _MensajeError(this.mensaje);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: UtbColores.error, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(mensaje, style: const TextStyle(color: UtbColores.error))),
        ],
      ),
    );
  }
}
