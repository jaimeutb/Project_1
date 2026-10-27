import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl;

import '../config/api_config.dart';
import '../models/material.dart' as modelo;
import '../models/valoracion.dart';
import '../services/api_client.dart';
import '../services/material_service.dart';
import '../state/session.dart';
import '../theme/utb_theme.dart';
import '../widgets/material_card.dart' show tipoDeArchivo;
import '../widgets/tutor_ia_panel.dart';

/// RF-05: visualización del material. Desde aquí también se descarga
/// (RF-05), se valora (RF-08) y se reporta (RF-09).
class MaterialDetailScreen extends StatefulWidget {
  final int materialId;
  const MaterialDetailScreen({super.key, required this.materialId});

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  modelo.Material? _material;
  List<Valoracion> _valoraciones = [];
  bool _cargando = true;
  String? _error;

  String? get _token => context.read<Session>().token;
  MaterialService get _service => MaterialService(_token);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final material = await _service.obtener(widget.materialId);
      final valoraciones = await _service.listarValoraciones(widget.materialId);
      setState(() {
        _material = material;
        _valoraciones = valoraciones;
      });
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _descargar() async {
    if (_material == null) return;
    final uri = ApiConfig.archivo(_material!.archivoUrl);
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  Future<void> _valorar() async {
    int puntuacion = 5;
    final comentarioCtrl = TextEditingController();

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Valorar material'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(5, (i) {
                  final valor = i + 1;
                  return IconButton(
                    icon: Icon(
                      valor <= puntuacion ? Icons.star : Icons.star_border,
                      color: UtbColores.ambar,
                    ),
                    onPressed: () => setDialogState(() => puntuacion = valor),
                  );
                }),
              ),
              TextField(
                controller: comentarioCtrl,
                decoration: const InputDecoration(labelText: '¿Qué tan útil fue?'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Enviar'),
            ),
          ],
        ),
      ),
    );

    if (confirmado != true) return;
    try {
      await _service.valorar(widget.materialId,
          puntuacion: puntuacion, comentario: comentarioCtrl.text.trim());
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  Future<void> _reportar() async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const DialogoReportar(),
    );

    if (motivo == null) return;
    try {
      await _service.reportar(widget.materialId, motivo: motivo);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Reporte enviado. Gracias.')));
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_material?.titulo ?? 'Material')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: UtbColores.error)))
              : _material == null
                  ? const SizedBox.shrink()
                  : LayoutBuilder(builder: (context, constraints) {
                      final ficha = _fichaDelMaterial(_material!);
                      final tutor = TutorIaPanel(materialId: widget.materialId, token: _token);
                      final comentarios = _comentarios();
                      // En pantallas anchas el Tutor IA va al lado de la ficha; en el
                      // celular, debajo (RNF-03).
                      final contenido = constraints.maxWidth >= 1000
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        ficha,
                                        const SizedBox(height: 16),
                                        comentarios,
                                      ]),
                                ),
                                const SizedBox(width: 20),
                                Expanded(flex: 6, child: tutor),
                              ],
                            )
                          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              ficha,
                              const SizedBox(height: 16),
                              tutor,
                              const SizedBox(height: 16),
                              comentarios,
                            ]);
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: contenido,
                          ),
                        ),
                      );
                    }),
    );
  }

  Widget _fichaDelMaterial(modelo.Material m) {
    final (iconoArchivo, tipoArchivo) = tipoDeArchivo(m.archivoUrl);
    return TarjetaUtb(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: UtbColores.verde10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconoArchivo, color: UtbColores.verde, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.asignaturaNombre,
                        style: const TextStyle(
                            color: UtbColores.azul, fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(m.titulo,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800, color: UtbColores.texto)),
                  ],
                ),
              ),
            ],
          ),
          if (m.descripcion != null && m.descripcion!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(m.descripcion!, style: const TextStyle(height: 1.45)),
          ],
          const SizedBox(height: 16),
          Wrap(spacing: 24, runSpacing: 12, children: [
            _Info('Autor', m.autorVisible),
            if (m.profesor != null) _Info('Profesor', m.profesor!),
            if (m.periodoAcademico != null) _Info('Periodo', m.periodoAcademico!),
            _Info('Estado', m.estadoVisible),
            _Info('Calificación',
                '${m.calificacionPromedio.toStringAsFixed(1)} (${m.totalValoraciones})'),
            _Info('Archivo', tipoArchivo),
          ]),
          const SizedBox(height: 20),
          Wrap(spacing: 10, runSpacing: 10, children: [
            FilledButton.icon(
              onPressed: _descargar,
              icon: const Icon(Icons.download),
              label: const Text('Descargar'),
            ),
            OutlinedButton.icon(
              onPressed: _valorar,
              icon: const Icon(Icons.star_border),
              label: const Text('Valorar'),
            ),
            OutlinedButton.icon(
              onPressed: _reportar,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('Reportar'),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _comentarios() {
    return TarjetaUtb(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Comentarios (${_valoraciones.length})',
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16, color: UtbColores.azulOscuro)),
          const SizedBox(height: 8),
          if (_valoraciones.isEmpty)
            const Text('Aún no hay comentarios. ¿Te sirvió? Valóralo para ayudar a otros.',
                style: TextStyle(color: UtbColores.textoSecundario)),
          ..._valoraciones.map((v) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    v.puntuacion,
                    (_) => const Icon(Icons.star_rounded, size: 16, color: UtbColores.ambar),
                  ),
                ),
                title: Text(v.comentario?.isNotEmpty == true ? v.comentario! : '(sin comentario)'),
                subtitle: Text(v.autor),
              )),
        ],
      ),
    );
  }
}

/// Ventana para reportar un material (RF-09). Devuelve el motivo escrito, o null
/// si se cancela. «Reportar» se activa solo cuando hay un motivo (H-03): antes,
/// un reporte sin motivo cerraba la ventana sin enviar nada y sin avisar.
class DialogoReportar extends StatefulWidget {
  const DialogoReportar({super.key});

  @override
  State<DialogoReportar> createState() => _DialogoReportarState();
}

class _DialogoReportarState extends State<DialogoReportar> {
  final _motivoCtrl = TextEditingController();

  String get _motivo => _motivoCtrl.text.trim();

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reportar material'),
      content: TextField(
        controller: _motivoCtrl,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Motivo',
          hintText: 'Ej. desactualizado, incorrecto, profesor distinto…',
          helperText: _motivo.isEmpty ? 'Escriba el motivo para enviar el reporte.' : null,
        ),
        maxLines: 3,
        onChanged: (_) => setState(() {}),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _motivo.isEmpty ? null : () => Navigator.of(context).pop(_motivo),
          child: const Text('Reportar'),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  final String etiqueta;
  final String valor;
  const _Info(this.etiqueta, this.valor);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: const TextStyle(fontSize: 11, color: UtbColores.textoSecundario)),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
