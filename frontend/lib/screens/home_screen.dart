import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asignatura.dart';
import '../models/material.dart' as modelo;
import '../services/api_client.dart';
import '../services/asignatura_service.dart';
import '../services/material_service.dart';
import '../state/session.dart';
import '../theme/utb_theme.dart';
import '../widgets/logo_utb.dart';
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
    final nuevo = await showDialog<modelo.Material>(
      context: context,
      builder: (_) => DialogoSubirMaterial(asignaturas: _asignaturas, token: _token),
    );
    if (nuevo == null || !mounted) return;

    // H-04: se confirma la carga y se quitan los filtros para que el material
    // nuevo aparezca primero en la lista.
    _textoCtrl.clear();
    setState(() {
      _semestreSeleccionado = null;
      _asignaturaSeleccionada = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(nuevo.esAnonimo
          ? 'Material publicado de forma anónima.'
          : 'Material publicado.'),
      action: SnackBarAction(label: 'Ver', onPressed: () => _abrirDetalle(nuevo)),
    ));
    _buscar();
  }

  /// Abre una pantalla de administración y, al volver, recarga asignaturas y
  /// material por si cambiaron.
  Future<void> _abrirAdministracion(Widget pantalla) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _cargarAsignaturas();
  }

  bool get _hayFiltros =>
      _textoCtrl.text.isNotEmpty || _semestreSeleccionado != null || _asignaturaSeleccionada != null;

  void _quitarFiltros() {
    _textoCtrl.clear();
    setState(() {
      _semestreSeleccionado = null;
      _asignaturaSeleccionada = null;
    });
    _buscar();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final anchoPantalla = MediaQuery.sizeOf(context).width;

    final buscador = TextField(
      controller: _textoCtrl,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Buscar por título, tema o asignatura…',
        isDense: true,
        suffixIcon: IconButton(
          tooltip: 'Buscar',
          icon: const Icon(Icons.arrow_forward),
          onPressed: _buscar,
        ),
      ),
      onSubmitted: (_) => _buscar(),
    );

    // `initialValue` reemplaza a `value` desde Flutter 3.35, pero no existe en
    // Flutter 3.24, con el que el proyecto también compila; por eso se mantiene
    // `value` en las listas desplegables.
    final filtroSemestre = DropdownButtonFormField<String?>(
      // ignore: deprecated_member_use
      value: _semestreSeleccionado,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Semestre', isDense: true),
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
      // ignore: deprecated_member_use
      value: _asignaturaSeleccionada,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Asignatura', isDense: true),
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

    // RNF-03: en pantallas angostas (navegador móvil) los filtros se apilan.
    final filtros = TarjetaUtb(
      padding: const EdgeInsets.all(16),
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
                  const SizedBox(height: 10),
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
    );

    final encabezadoResultados = Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _cargando
                  ? 'Buscando material…'
                  : _materiales.length == 1
                      ? '1 material'
                      : '${_materiales.length} materiales',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800, color: UtbColores.azulOscuro),
            ),
          ),
          if (_hayFiltros)
            TextButton.icon(
              onPressed: _quitarFiltros,
              icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
              label: const Text('Quitar filtros'),
            ),
        ],
      ),
    );

    // Las tarjetas se acomodan en 1, 2 o 3 columnas según el ancho, y la lista
    // se construye por filas a medida que se desplaza (RNF-02 con mucho material).
    final columnas = anchoPantalla >= 1100 ? 3 : anchoPantalla >= 720 ? 2 : 1;
    final filas = (_materiales.length / columnas).ceil();
    final margenLateral = anchoPantalla > 1240 ? (anchoPantalla - 1200) / 2 : 16.0;

    final encabezado = <Widget>[
      _BannerBienvenida(nombre: session.usuario?.nombre),
      const SizedBox(height: 16),
      filtros,
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: UtbColores.error)),
        ),
      encabezadoResultados,
      if (_cargando)
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_materiales.isEmpty)
        const TarjetaUtb(
          child: Column(
            children: [
              Icon(Icons.search_off, size: 40, color: UtbColores.textoSecundario),
              SizedBox(height: 8),
              Text('No se encontró material con estos criterios.', textAlign: TextAlign.center),
            ],
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        titleSpacing: 16,
        title: anchoPantalla >= 600
            ? const Row(
                children: [
                  LogoUtb(altura: 46),
                  SizedBox(width: 16),
                  SizedBox(height: 32, child: VerticalDivider(width: 1)),
                  SizedBox(width: 16),
                  Flexible(child: Text('Apoyo Académico', overflow: TextOverflow.ellipsis)),
                ],
              )
            : const Row(
                children: [
                  LogoUtb(altura: 34, soloSimbolo: true),
                  SizedBox(width: 10),
                  Flexible(child: Text('Apoyo Académico', overflow: TextOverflow.ellipsis)),
                ],
              ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(3),
          child: SizedBox(
            height: 3,
            width: double.infinity,
            child: DecoratedBox(decoration: BoxDecoration(gradient: UtbColores.degradado)),
          ),
        ),
        actions: [
          if (session.esAdministrador)
            PopupMenuButton<Widget>(
              tooltip: 'Administración',
              onSelected: _abrirAdministracion,
              // En pantallas anchas el menú muestra su nombre para que se encuentre
              // fácilmente; en el celular queda solo el ícono para ahorrar espacio.
              child: anchoPantalla >= 600
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
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _subirMaterial,
        icon: const Icon(Icons.upload_file),
        label: const Text('Subir material'),
      ),
      body: ListView.builder(
        // Espacio al final para que el botón flotante no tape la última tarjeta.
        padding: EdgeInsets.fromLTRB(margenLateral, 16, margenLateral, 96),
        itemCount: encabezado.length + (_cargando ? 0 : filas),
        itemBuilder: (context, i) {
          if (i < encabezado.length) return encabezado[i];
          final inicio = (i - encabezado.length) * columnas;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columnas; c++) ...[
                    if (c > 0) const SizedBox(width: 12),
                    Expanded(
                      child: inicio + c < _materiales.length
                          ? MaterialCard(
                              material: _materiales[inicio + c],
                              onTap: () => _abrirDetalle(_materiales[inicio + c]),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bienvenida con la propuesta del Tutor IA: invita a abrir un material.
class _BannerBienvenida extends StatelessWidget {
  final String? nombre;
  const _BannerBienvenida({required this.nombre});

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width >= 720;
    final primerNombre = nombre?.trim().split(' ').first ?? '';
    return Container(
      padding: EdgeInsets.all(ancho ? 28 : 20),
      decoration: BoxDecoration(
        gradient: UtbColores.degradado,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primerNombre.isEmpty ? 'Hola' : 'Hola, $primerNombre',
                  style: const TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Prepárate para tus parciales con el Tutor IA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: ancho ? 26 : 20,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Abre cualquier material: el tutor te lo explica, te hace un quiz y '
                  'resuelve tus dudas paso a paso.',
                  style: TextStyle(color: Color(0xE6FFFFFF), height: 1.4),
                ),
                const SizedBox(height: 14),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PildoraBanner(Icons.lightbulb_outline, 'Explicaciones'),
                    _PildoraBanner(Icons.quiz_outlined, 'Quices de práctica'),
                    _PildoraBanner(Icons.forum_outlined, 'Resuelve dudas'),
                  ],
                ),
              ],
            ),
          ),
          if (ancho) ...[
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const LogoUtb(altura: 88, soloSimbolo: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _PildoraBanner extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _PildoraBanner(this.icono, this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(texto, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

/// R-02: tipos y tamaño de archivo que acepta el servidor.
const extensionesPermitidas = {'pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx', 'zip'};
const tamanoMaximoArchivo = 25 * 1024 * 1024; // 25 MB
const textoArchivosPermitidos = 'PDF, imagen (PNG o JPG), Word o ZIP; máx. 25 MB.';

/// Revisa el archivo elegido antes de subirlo, para avisar de inmediato (H-06).
/// Devuelve el mensaje de error, o null si el archivo se puede subir.
String? validarArchivo(String nombre, int bytes) {
  final punto = nombre.lastIndexOf('.');
  final extension = punto < 0 ? '' : nombre.substring(punto + 1).toLowerCase();
  if (!extensionesPermitidas.contains(extension)) {
    return 'Tipo de archivo no permitido: use PDF, imagen (PNG o JPG), Word o ZIP.';
  }
  if (bytes > tamanoMaximoArchivo) return 'El archivo supera el máximo de 25 MB.';
  return null;
}

/// Formulario de carga de material (RF-06/RF-07/RF-11), usado desde el FAB.
/// Devuelve el material creado, o null si se cancela.
class DialogoSubirMaterial extends StatefulWidget {
  final List<Asignatura> asignaturas;
  final String? token;
  const DialogoSubirMaterial({super.key, required this.asignaturas, required this.token});

  @override
  State<DialogoSubirMaterial> createState() => _DialogoSubirMaterialState();
}

class _DialogoSubirMaterialState extends State<DialogoSubirMaterial> {
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
    if (resultado == null || resultado.files.isEmpty) return;
    final archivo = resultado.files.first;
    final error = validarArchivo(archivo.name, archivo.size);
    setState(() {
      _archivo = error == null ? archivo : null;
      _error = error;
    });
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
      final nuevo = await MaterialService(widget.token).subir(
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
      Navigator.of(context).pop(nuevo);
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
                // H-05: el interruptor va primero para que el teclado del celular
                // no lo tape mientras se completan los campos de texto.
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Subir de forma anónima'),
                  subtitle: const Text('Su nombre no se mostrará en el material.'),
                  value: _anonimo,
                  onChanged: (v) => setState(() => _anonimo = v),
                ),
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
                  // ignore: deprecated_member_use
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
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _elegirArchivo,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_archivo?.name ?? 'Elegir archivo'),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    textoArchivosPermitidos,
                    style: TextStyle(fontSize: 12, color: UtbColores.textoSecundario),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: UtbColores.error)),
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
