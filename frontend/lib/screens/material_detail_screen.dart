import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl;

import '../config/api_config.dart';
import '../models/material.dart';
import '../models/valoracion.dart';
import '../services/api_client.dart';
import '../services/material_service.dart';
import '../state/session.dart';

/// RF-05: visualización del material. Desde aquí también se descarga
/// (RF-05), se valora (RF-08) y se reporta (RF-09).
class MaterialDetailScreen extends StatefulWidget {
  final int materialId;
  const MaterialDetailScreen({super.key, required this.materialId});

  @override
  State<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends State<MaterialDetailScreen> {
  Material? _material;
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
                      color: Colors.amber,
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
    final motivoCtrl = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reportar material'),
        content: TextField(
          controller: motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo',
            hintText: 'Ej. desactualizado, incorrecto, profesor distinto…',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reportar'),
          ),
        ],
      ),
    );

    if (confirmado != true || motivoCtrl.text.trim().isEmpty) return;
    try {
      await _service.reportar(widget.materialId, motivo: motivoCtrl.text.trim());
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
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _material == null
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 640),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_material!.asignaturaNombre,
                                style: const TextStyle(color: Colors.black54)),
                            const SizedBox(height: 8),
                            if (_material!.descripcion != null)
                              Text(_material!.descripcion!),
                            const SizedBox(height: 12),
                            Wrap(spacing: 16, runSpacing: 4, children: [
                              _Info('Autor', _material!.autorVisible),
                              if (_material!.profesor != null)
                                _Info('Profesor', _material!.profesor!),
                              if (_material!.periodoAcademico != null)
                                _Info('Periodo', _material!.periodoAcademico!),
                              _Info('Estado', _material!.estado),
                              _Info('Calificación',
                                  '${_material!.calificacionPromedio.toStringAsFixed(1)} (${_material!.totalValoraciones})'),
                            ]),
                            const SizedBox(height: 20),
                            Wrap(spacing: 12, children: [
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
                            const Divider(height: 40),
                            Text('Comentarios (${_valoraciones.length})',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            ..._valoraciones.map((v) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(
                                      v.puntuacion,
                                      (_) => const Icon(Icons.star,
                                          size: 14, color: Colors.amber),
                                    ),
                                  ),
                                  title: Text(v.comentario?.isNotEmpty == true
                                      ? v.comentario!
                                      : '(sin comentario)'),
                                  subtitle: Text(v.autor),
                                )),
                          ],
                        ),
                      ),
                    ),
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
        Text(etiqueta, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
