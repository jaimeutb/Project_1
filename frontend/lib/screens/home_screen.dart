import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asignatura.dart';
import '../models/material.dart' as modelo;
import '../services/api_client.dart';
import '../services/asignatura_service.dart';
import '../services/material_service.dart';
import '../state/session.dart';
import '../widgets/material_card.dart';
import 'admin_asignaturas_screen.dart';
import 'admin_materiales_screen.dart';
import 'admin_reportes_screen.dart';
import 'admin_usuarios_screen.dart';
import 'login_screen.dart';
import 'material_detail_screen.dart';

/// Pantalla principal: búsqueda y filtro de material (RF-03/RF-04) y acceso
/// a subir material propio (RF-06/RF-07). Para el administrador, da acceso a
/// la gestión de material, reportes, asignaturas y usuarios (RF-10/12/13).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _textoCtrl = TextEditingController();
  List<Asignatura> _asignaturas = [];
  String? _semestreSeleccionado;
  Asignatura? _asignaturaSeleccionada;
  List<modelo.Material> _materiales = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarAsignaturas();
  }

  String? get _token => context.read<Session>().token;

  /// Semestres disponibles para el filtro RF-04, tomados de las asignaturas.
  List<String> get _semestres {
    final semestres = _asignaturas.map((a) => a.semestre).toSet().toList();
    semestres.sort((a, b) => (int.tryParse(a) ?? 999).compareTo(int.tryParse(b) ?? 999));
    return semestres;
  }

  /// Si hay un semestre elegido, solo se ofrecen sus asignaturas.
  List<Asignatura> get _asignaturasFiltradas => _semestreSeleccionado == null
      ? _asignaturas
      : _asignaturas.where((a) => a.semestre == _semestreSeleccionado).toList();

  Future<void> _cargarAsignaturas() async {
    try {
      final asignaturas = await AsignaturaService(_token).listar();
      setState(() {
        _asignaturas = asignaturas;
        // Por si el administrador desactivó la asignatura o el semestre elegido.
        if (!asignaturas.contains(_asignaturaSeleccionada)) _asignaturaSeleccionada = null;
        if (!_semestres.contains(_semestreSeleccionado)) _semestreSeleccionado = null;
      });
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
        semestre: _semestreSeleccionado,
        texto: _textoCtrl.text.trim(),
      );
      setState(() => _materiales = resultados);
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _abrirDetalle(modelo.Material material) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MaterialDetailScreen(materialId: material.id)),
    );
    _buscar();
  }

  Future<void> _subirMaterial() async {
    if (_asignaturas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Aún no hay asignaturas: el administrador debe crearlas primero.'),
      ));
      return;
    }
    final resultado = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoSubirMaterial(asignaturas: _asignaturas, token: _token),
    );
    if (resultado == true) _buscar();
  }

  /// Abre una pantalla de administración y, al volver, recarga asignaturas y
  /// material por si cambiaron.
  Future<void> _abrirAdministracion(Widget pantalla) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _cargarAsignaturas();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();

    final buscador = TextField(
      controller: _textoCtrl,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Buscar por título o tema…',
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          tooltip: 'Buscar',
          icon: const Icon(Icons.arrow_forward),
          onPressed: _buscar,
        ),
      ),
      onSubmitted: (_) => _buscar(),
    );

    final filtroSemestre = DropdownButtonFormField<String?>(
      value: _semestreSeleccionado,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Semestre',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todos')),
        ..._semestres.map((s) => DropdownMenuItem(value: s, child: Text(s))),
      ],
      onChanged: (v) {
        setState(() {
          _semestreSeleccionado = v;
          if (v != null && _asignaturaSeleccionada?.semestre != v) {
            _asignaturaSeleccionada = null;
          }
        });
        _buscar();
      },
    );

    final filtroAsignatura = DropdownButtonFormField<Asignatura?>(
      value: _asignaturaSeleccionada,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Asignatura',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todas')),
        ..._asignaturasFiltradas.map(
          (a) => DropdownMenuItem(
            value: a,
            child: Text(a.toString(), overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: (v) {
        setState(() => _asignaturaSeleccionada = v);
        _buscar();
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plataforma de Apoyo Académico'),
        actions: [
          if (session.esAdministrador)
            PopupMenuButton<Widget>(
              tooltip: 'Administración',
              onSelected: _abrirAdministracion,
              // En pantallas anchas el menú muestra su nombre para que se encuentre
              // fácilmente; en el celular queda solo el ícono para ahorrar espacio.
              child: MediaQuery.sizeOf(context).width >= 600
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.admin_panel_settings_outlined),
                          SizedBox(width: 6),
                          Text('Administración'),
                          Icon(Icons.arrow_drop_down),
                        ],
                      ),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.admin_panel_settings_outlined),
                    ),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: AdminMaterialesScreen(),
                  child: ListTile(leading: Icon(Icons.folder_open), title: Text('Gestionar material')),
                ),
                PopupMenuItem(
                  value: AdminReportesScreen(),
                  child: ListTile(leading: Icon(Icons.flag_outlined), title: Text('Revisar reportes')),
                ),
                PopupMenuItem(
                  value: AdminAsignaturasScreen(),
                  child: ListTile(leading: Icon(Icons.menu_book_outlined), title: Text('Asignaturas')),
                ),
                PopupMenuItem(
                  value: AdminUsuariosScreen(),
                  child: ListTile(leading: Icon(Icons.group_outlined), title: Text('Usuarios')),
                ),
              ],
            ),
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
            // RNF-03: en pantallas angostas (navegador móvil) los filtros se apilan.
            child: LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 720
                  ? Row(
                      children: [
                        Expanded(flex: 2, child: buscador),
                        const SizedBox(width: 12),
                        Expanded(child: filtroSemestre),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: filtroAsignatura),
                      ],
                    )
                  : Column(
                      children: [
                        buscador,
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: filtroSemestre),
                            const SizedBox(width: 8),
                            Expanded(flex: 2, child: filtroAsignatura),
                          ],
                        ),
                      ],
                    ),
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
                        // Espacio al final para que el botón flotante no tape la última tarjeta.
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
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
                  isExpanded: true,
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
