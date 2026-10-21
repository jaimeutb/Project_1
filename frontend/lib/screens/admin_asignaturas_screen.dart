import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asignatura.dart';
import '../services/api_client.dart';
import '../services/asignatura_service.dart';
import '../state/session.dart';

/// RF-13: el administrador crea, edita y desactiva asignaturas. Una asignatura
/// desactivada deja de aparecer en el buscador y no admite material nuevo.
class AdminAsignaturasScreen extends StatefulWidget {
  const AdminAsignaturasScreen({super.key});

  @override
  State<AdminAsignaturasScreen> createState() => _AdminAsignaturasScreenState();
}

class _AdminAsignaturasScreenState extends State<AdminAsignaturasScreen> {
  List<Asignatura> _asignaturas = [];
  bool _cargando = true;
  String? _error;

  String? get _token => context.read<Session>().token;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final asignaturas = await AsignaturaService(_token).listar(incluirInactivas: true);
      setState(() => _asignaturas = asignaturas);
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    try {
      await accion();
      _cargar();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensaje)));
    }
  }

  Future<void> _abrirFormulario([Asignatura? asignatura]) async {
    final datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _DialogoAsignatura(asignatura: asignatura),
    );
    if (datos == null) return;
    final service = AsignaturaService(_token);
    await _ejecutar(() async {
      if (asignatura == null) {
        await service.crear(
            nombre: datos['nombre']!, codigo: datos['codigo']!, semestre: datos['semestre']!);
      } else {
        await service.actualizar(asignatura.id, datos);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar asignaturas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva asignatura'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _asignaturas.isEmpty
                  ? const Center(child: Text('Aún no hay asignaturas registradas.'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 80),
                      itemCount: _asignaturas.length,
                      itemBuilder: (context, i) {
                        final a = _asignaturas[i];
                        return ListTile(
                          title: Text(a.nombre),
                          subtitle: Text(
                              '${a.codigo} · Semestre ${a.semestre}${a.activo ? '' : ' · Desactivada'}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Editar',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _abrirFormulario(a),
                              ),
                              Switch(
                                value: a.activo,
                                onChanged: (activo) => _ejecutar(() =>
                                    AsignaturaService(_token).actualizar(a.id, {'activo': activo})),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

/// Formulario para crear o editar una asignatura. Devuelve los campos o null.
class _DialogoAsignatura extends StatefulWidget {
  final Asignatura? asignatura;
  const _DialogoAsignatura({this.asignatura});

  @override
  State<_DialogoAsignatura> createState() => _DialogoAsignaturaState();
}

class _DialogoAsignaturaState extends State<_DialogoAsignatura> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreCtrl = TextEditingController(text: widget.asignatura?.nombre);
  late final _codigoCtrl = TextEditingController(text: widget.asignatura?.codigo);
  late final _semestreCtrl = TextEditingController(text: widget.asignatura?.semestre);

  String? _requerido(String? v) => (v == null || v.trim().isEmpty) ? 'Requerido.' : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.asignatura == null ? 'Nueva asignatura' : 'Editar asignatura'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: _requerido,
              ),
              TextFormField(
                controller: _codigoCtrl,
                decoration: const InputDecoration(labelText: 'Código (ej. MAT101)'),
                validator: _requerido,
              ),
              TextFormField(
                controller: _semestreCtrl,
                decoration: const InputDecoration(labelText: 'Semestre (ej. 1)'),
                validator: _requerido,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop({
              'nombre': _nombreCtrl.text.trim(),
              'codigo': _codigoCtrl.text.trim(),
              'semestre': _semestreCtrl.text.trim(),
            });
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
