import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asignatura.dart';
import '../models/material.dart';
import '../services/api_client.dart';
import '../services/asignatura_service.dart';
import '../services/material_service.dart';
import '../state/session.dart';
import '../widgets/material_card.dart';
import 'admin_materiales_screen.dart';
import 'admin_reportes_screen.dart';
import 'login_screen.dart';
import 'material_detail_screen.dart';

/// Pantalla principal: búsqueda y filtro de material (RF-03/RF-04) y acceso
/// a subir material propio (RF-06/RF-07).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textoCtrl = TextEditingController();
  List<Asignatura> _asignaturas = [];
  Asignatura? _asignaturaSeleccionada;
  List<Material> _materiales = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarAsignaturas();
  }

  String? get _token => context.read<Session>().token;

  Future<void> _cargarAsignaturas() async {
    try {
      final asignaturas = await AsignaturaService(_token).listar();
      setState(() => _asignaturas = asignaturas);
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      await _buscar();
    }
  }

  Future<void> _buscar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await MaterialService(_token).buscar(
        asignaturaId: _asignaturaSeleccionada?.id,
        texto: _textoCtrl.text.trim(),
      );
      setState(() => _materiales = resultados);
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      setState(() => _cargando = false);
    }
  }

  Future<void> _abrirDetalle(Material material) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MaterialDetailScreen(materialId: material.id)),
    );
    _buscar();
  }

  Future<void> _subirMaterial() async {
    if (_asignaturas.isEmpty) return;
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoSubirMaterial(asignaturas: _asignaturas, token: _token),
    );
    if (resultado == true) _buscar();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plataforma de Apoyo Académico'),
        actions: [
          if (session.esAdministrador) ...[
            IconButton(
              tooltip: 'Gestionar material',
              icon: const Icon(Icons.folder_open),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminMaterialesScreen()),
              ),
            ),
            IconButton(
              tooltip: 'Revisar reportes',
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminReportesScreen()),
              ),
            ),
          ],
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await session.cerrarSesion();
              if (!context.mounted) return;
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _subirMaterial,
        icon: const Icon(Icons.upload_file),
        label: const Text('Subir material'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _textoCtrl,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar por título o tema…',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<Asignatura?>(
                    value: _asignaturaSeleccionada,
                    decoration: const InputDecoration(
                      labelText: 'Asignatura',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Todas')),
                      ..._asignaturas.map(
                        (a) => DropdownMenuItem(value: a, child: Text(a.toString())),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _asignaturaSeleccionada = v);
                      _buscar();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: _buscar, child: const Text('Buscar')),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _materiales.isEmpty
                    ? const Center(child: Text('No se encontró material con estos criterios.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _materiales.length,
                        itemBuilder: (context, i) => MaterialCard(
                          material: _materiales[i],
                          onTap: () => _abrirDetalle(_materiales[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// Formulario de carga de material (RF-06/RF-07/RF-11), usado desde el FAB.
class _DialogoSubirMaterial extends StatefulWidget {
  final List<Asignatura> asignaturas;
  final String? token;
  const _DialogoSubirMaterial({required this.asignaturas, required this.token});

  @override
  State<_DialogoSubirMaterial> createState() => _DialogoSubirMaterialState();
}

class _DialogoSubirMaterialState extends State<_DialogoSubirMaterial> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _profesorCtrl = TextEditingController();
  final _periodoCtrl = TextEditingController();
  Asignatura? _asignatura;
  bool _anonimo = false;
  PlatformFile? _archivo;
  bool _cargando = false;
  String? _error;

  Future<void> _elegirArchivo() async {
    final resultado = await FilePicker.platform.pickFiles(withData: true);
    if (resultado != null && resultado.files.isNotEmpty) {
      setState(() => _archivo = resultado.files.first);
    }
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate() || _asignatura == null) return;
    if (_archivo == null || _archivo!.bytes == null) {
      setState(() => _error = 'Seleccione un archivo.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await MaterialService(widget.token).subir(
        titulo: _tituloCtrl.text.trim(),
        descripcion: _descripcionCtrl.text.trim(),
        asignaturaId: _asignatura!.id,
        profesor: _profesorCtrl.text.trim(),
        periodoAcademico: _periodoCtrl.text.trim(),
        esAnonimo: _anonimo,
        archivoBytes: _archivo!.bytes!,
        nombreArchivo: _archivo!.name,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Subir material'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _tituloCtrl,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requerido.' : null,
                ),
                TextFormField(
                  controller: _descripcionCtrl,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
                DropdownButtonFormField<Asignatura>(
                  value: _asignatura,
                  decoration: const InputDecoration(labelText: 'Asignatura'),
                  items: widget.asignaturas
                      .map((a) => DropdownMenuItem(value: a, child: Text(a.toString())))
                      .toList(),
                  onChanged: (v) => setState(() => _asignatura = v),
                  validator: (v) => v == null ? 'Requerido.' : null,
                ),
                TextFormField(
                  controller: _profesorCtrl,
                  decoration: const InputDecoration(labelText: 'Profesor (opcional)'),
                ),
                TextFormField(
                  controller: _periodoCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Periodo académico (ej. 2026-2)'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Subir de forma anónima'),
                  value: _anonimo,
                  onChanged: (v) => setState(() => _anonimo = v),
                ),
                OutlinedButton.icon(
                  onPressed: _elegirArchivo,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_archivo?.name ?? 'Elegir archivo'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _cargando ? null : _enviar,
          child: _cargando
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Subir'),
        ),
      ],
    );
  }
}
