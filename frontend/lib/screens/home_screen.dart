import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/asignatura.dart';
import '../models/material.dart' as modelo;
import '../services/api_client.dart';
import '../services/asignatura_service.dart';
import '../services/material_service.dart';
import '../state/session.dart';
import '../theme/utb_theme.dart';
import '../widgets/dialogo_subir_material.dart';
import '../widgets/logo_utb.dart';
import '../widgets/material_card.dart';
import 'admin_asignaturas_screen.dart';
import 'admin_materiales_screen.dart';
import 'admin_reportes_screen.dart';
import 'admin_usuarios_screen.dart';
import 'login_screen.dart';
import 'material_detail_screen.dart';
import 'mis_aportes_screen.dart';
import 'simulacro_screen.dart';

export '../widgets/dialogo_subir_material.dart'
    show DialogoSubirMaterial, validarArchivo, textoArchivosPermitidos, tamanoMaximoArchivo;

enum Seccion { inicio, explorar, simulacro, aportes }

/// Pantalla principal. En computador, barra lateral con las secciones; en el
/// celular, barra de navegación inferior (RNF-03). Secciones: Inicio, Explorar
/// (RF-03/RF-04), Simulacro IA (RF-18) y Mis aportes (RF-06/RF-17). Para el
/// administrador, acceso a la gestión de material, reportes, asignaturas y
/// usuarios (RF-10/12/13).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Seccion _seccion = Seccion.inicio;

  // Explorar (RF-03/RF-04)
  final _textoCtrl = TextEditingController();
  List<Asignatura> _asignaturas = [];
  String? _semestreSeleccionado;
  Asignatura? _asignaturaSeleccionada;
  String? _tipoSeleccionado;
  List<modelo.Material> _materiales = [];
  bool _cargando = true;
  String? _error;

  // Inicio
  List<modelo.Material> _recientes = [];
  final _aportesKey = GlobalKey<MisAportesPaginaState>();

  @override
  void initState() {
    super.initState();
    _cargarAsignaturas();
  }

  @override
  void dispose() {
    _textoCtrl.dispose();
    super.dispose();
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

  bool get _hayFiltros =>
      _textoCtrl.text.isNotEmpty ||
      _semestreSeleccionado != null ||
      _asignaturaSeleccionada != null ||
      _tipoSeleccionado != null;

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
    } catch (_) {
      setState(() => _error = 'No fue posible conectar con el servidor.');
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
        tipo: _tipoSeleccionado,
      );
      setState(() {
        _materiales = resultados;
        if (!_hayFiltros) _recientes = resultados.take(6).toList();
      });
    } on ApiException catch (e) {
      setState(() => _error = e.mensaje);
    } catch (_) {
      setState(() => _error = 'No fue posible conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _quitarFiltros() {
    _textoCtrl.clear();
    setState(() {
      _semestreSeleccionado = null;
      _asignaturaSeleccionada = null;
      _tipoSeleccionado = null;
    });
    _buscar();
  }

  void _irA(Seccion seccion) => setState(() => _seccion = seccion);

  /// Desde Inicio: buscar un texto o abrir una asignatura en Explorar.
  void _explorar({String? texto, Asignatura? asignatura}) {
    if (texto != null) _textoCtrl.text = texto;
    setState(() {
      if (asignatura != null) {
        _asignaturaSeleccionada = asignatura;
        _semestreSeleccionado = null;
      }
      _seccion = Seccion.explorar;
    });
    _buscar();
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
      _tipoSeleccionado = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(nuevo.estado == 'pendiente'
          ? 'Material enviado: quedó pendiente de revisión.'
          : nuevo.esAnonimo
              ? 'Material publicado de forma anónima.'
              : 'Material publicado.'),
      action: SnackBarAction(label: 'Ver', onPressed: () => _abrirDetalle(nuevo)),
    ));
    _aportesKey.currentState?.recargar();
    _cargarAsignaturas();
  }

  /// Abre una pantalla de administración y, al volver, recarga asignaturas y
  /// material por si cambiaron.
  Future<void> _abrirAdministracion(Widget pantalla) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _cargarAsignaturas();
  }

  Future<void> _cerrarSesion() async {
    await context.read<Session>().cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  // ---------------------------------------------------------------- estructura
  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final ancho = MediaQuery.sizeOf(context).width >= 1000;

    final pagina = _pagina(session);
    final fab = FloatingActionButton.extended(
      onPressed: _subirMaterial,
      icon: const Icon(Icons.upload_file),
      label: const Text('Subir material'),
    );

    if (ancho) {
      return Scaffold(
        floatingActionButton: fab,
        body: Row(
          children: [
            _BarraLateral(
              seccion: _seccion,
              onSeccion: _irA,
              nombre: session.usuario?.nombre ?? '',
              esAdministrador: session.esAdministrador,
              onAdministracion: _abrirAdministracion,
              onCerrarSesion: _cerrarSesion,
            ),
            Expanded(child: pagina),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 16,
        title: const Row(
          children: [
            LogoUtb(altura: 34, soloSimbolo: true),
            SizedBox(width: 10),
            Flexible(child: Text('Apoyo Académico', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          if (session.esAdministrador)
            PopupMenuButton<Widget>(
              tooltip: 'Administración',
              onSelected: _abrirAdministracion,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              itemBuilder: (context) => [
                for (final (pantalla, icono, nombre) in _opcionesAdministracion)
                  PopupMenuItem(
                    value: pantalla,
                    child: ListTile(leading: Icon(icono), title: Text(nombre)),
                  ),
              ],
            ),
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout),
            onPressed: _cerrarSesion,
          ),
        ],
      ),
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _seccion.index,
        onDestinationSelected: (i) => _irA(Seccion.values[i]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Explorar'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Simulacro'),
          NavigationDestination(icon: Icon(Icons.folder_shared_outlined), selectedIcon: Icon(Icons.folder_shared), label: 'Mis aportes'),
        ],
      ),
      body: pagina,
    );
  }

  Widget _pagina(Session session) {
    final ancho = MediaQuery.sizeOf(context).width;
    final margen = ancho >= 1000 ? 36.0 : 16.0;

    Widget desplazable(Widget hijo) => SingleChildScrollView(
          // Espacio al final para que el botón flotante no tape el contenido.
          padding: EdgeInsets.fromLTRB(margen, 24, margen, 104),
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1240), child: hijo),
          ),
        );

    return switch (_seccion) {
      Seccion.inicio => desplazable(_PaginaInicio(
          nombre: session.usuario?.nombre,
          asignaturas: _asignaturas,
          recientes: _recientes,
          cargando: _cargando && _recientes.isEmpty,
          onBuscar: (texto) => _explorar(texto: texto),
          onAsignatura: (a) => _explorar(asignatura: a),
          onSimulacro: () => _irA(Seccion.simulacro),
          onAbrir: _abrirDetalle,
        )),
      Seccion.explorar => _paginaExplorar(margen),
      Seccion.simulacro => desplazable(SimulacroPagina(
          asignaturas: _asignaturas,
          token: _token,
        )),
      Seccion.aportes => desplazable(MisAportesPagina(
          key: _aportesKey,
          token: _token,
          onAbrir: _abrirDetalle,
          onSubir: _subirMaterial,
        )),
    };
  }

  // ---------------------------------------------------------------- Explorar
  Widget _paginaExplorar(double margen) {
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

    // RF-17: tipo de material identificado por la IA.
    final filtroTipo = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (valor, nombre) in const [
          (null, 'Todo'),
          ('parcial', 'Parciales'),
          ('quiz', 'Quices'),
          ('taller', 'Talleres'),
          ('guia', 'Guías'),
          ('apuntes', 'Apuntes'),
        ])
          ChoiceChip(
            label: Text(nombre),
            selected: _tipoSeleccionado == valor,
            showCheckmark: false,
            onSelected: (_) {
              setState(() => _tipoSeleccionado = valor);
              _buscar();
            },
          ),
      ],
    );

    // RNF-03: en pantallas angostas (navegador móvil) los filtros se apilan.
    final filtros = TarjetaUtb(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
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
          const SizedBox(height: 12),
          filtroTipo,
        ],
      ),
    );

    final encabezado = <Widget>[
      const TituloSeccion('Explorar material',
          subtitulo: 'Parciales, quices y talleres de semestres anteriores.'),
      filtros,
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(_error!, style: const TextStyle(color: UtbColores.error)),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 12),
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
                    fontSize: 15, fontWeight: FontWeight.w800, color: UtbColores.azulOscuro),
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
      ),
      if (_cargando)
        const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
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

    return LayoutBuilder(builder: (context, constraints) {
      final anchoUtil = (constraints.maxWidth - 2 * margen).clamp(0, 1240).toDouble();
      final columnas = (anchoUtil / 300).floor().clamp(1, 4);
      final filas = _cargando ? 0 : (_materiales.length / columnas).ceil();
      final lateral = (constraints.maxWidth - anchoUtil) / 2;
      // La lista se construye por filas a medida que se desplaza (RNF-02).
      return ListView.builder(
        padding: EdgeInsets.fromLTRB(lateral, 0, lateral, 104),
        itemCount: encabezado.length + filas,
        itemBuilder: (context, i) {
          if (i < encabezado.length) return encabezado[i];
          final inicio = (i - encabezado.length) * columnas;
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var c = 0; c < columnas; c++) ...[
                    if (c > 0) const SizedBox(width: 14),
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
      );
    });
  }
}

const _opcionesAdministracion = [
  (AdminMaterialesScreen(), Icons.folder_open, 'Gestionar material'),
  (AdminReportesScreen(), Icons.flag_outlined, 'Revisar reportes'),
  (AdminAsignaturasScreen(), Icons.menu_book_outlined, 'Asignaturas'),
  (AdminUsuariosScreen(), Icons.group_outlined, 'Usuarios'),
];

// ---------------------------------------------------------------- barra lateral
class _BarraLateral extends StatelessWidget {
  final Seccion seccion;
  final ValueChanged<Seccion> onSeccion;
  final String nombre;
  final bool esAdministrador;
  final ValueChanged<Widget> onAdministracion;
  final VoidCallback onCerrarSesion;

  const _BarraLateral({
    required this.seccion,
    required this.onSeccion,
    required this.nombre,
    required this.esAdministrador,
    required this.onAdministracion,
    required this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    final iniciales = nombre.trim().isEmpty ? '?' : nombre.trim().substring(0, 1).toUpperCase();
    return Container(
      width: 268,
      decoration: const BoxDecoration(gradient: UtbColores.degradadoLateral),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(22, 24, 22, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: LogoUtb(altura: 54, sobreFondoOscuro: true),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 10, 22, 18),
              child: Text('APOYO ACADÉMICO',
                  style: TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 11,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700)),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  for (final (s, icono, texto) in const [
                    (Seccion.inicio, Icons.space_dashboard_outlined, 'Inicio'),
                    (Seccion.explorar, Icons.search, 'Explorar'),
                    (Seccion.simulacro, Icons.auto_awesome_outlined, 'Simulacro IA'),
                    (Seccion.aportes, Icons.folder_shared_outlined, 'Mis aportes'),
                  ])
                    _ItemLateral(
                      icono: icono,
                      texto: texto,
                      activo: seccion == s,
                      onTap: () => onSeccion(s),
                    ),
                  if (esAdministrador) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 22, 12, 8),
                      child: Text('Administración',
                          style: TextStyle(
                              color: Color(0x99FFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                    for (final (pantalla, icono, texto) in _opcionesAdministracion)
                      _ItemLateral(
                        icono: icono,
                        texto: texto,
                        activo: false,
                        onTap: () => onAdministracion(pantalla),
                      ),
                  ],
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x14FFFFFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: UtbColores.verde,
                    child: Text(iniciales,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        Text(esAdministrador ? 'Administrador' : 'Estudiante',
                            style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar sesión',
                    icon: const Icon(Icons.logout, color: Color(0xCCFFFFFF)),
                    onPressed: onCerrarSesion,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemLateral extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool activo;
  final VoidCallback onTap;

  const _ItemLateral({required this.icono, required this.texto, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: activo ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icono, size: 21, color: activo ? UtbColores.verde : const Color(0xCCFFFFFF)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(texto,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: activo ? UtbColores.azulOscuro : Colors.white,
                        fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                      )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Inicio
class _PaginaInicio extends StatelessWidget {
  final String? nombre;
  final List<Asignatura> asignaturas;
  final List<modelo.Material> recientes;
  final bool cargando;
  final ValueChanged<String> onBuscar;
  final ValueChanged<Asignatura> onAsignatura;
  final VoidCallback onSimulacro;
  final ValueChanged<modelo.Material> onAbrir;

  const _PaginaInicio({
    required this.nombre,
    required this.asignaturas,
    required this.recientes,
    required this.cargando,
    required this.onBuscar,
    required this.onAsignatura,
    required this.onSimulacro,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final primerNombre = nombre?.trim().split(' ').first ?? '';
    final totalMateriales = asignaturas.fold<int>(0, (s, a) => s + a.totalMateriales);

    return LayoutBuilder(builder: (context, constraints) {
      final porAncho = (constraints.maxWidth / 290).floor().clamp(1, 4);

      // [columnasFijas]: para las 4 tarjetas de funciones, 4, 2 o 1 columnas,
      // para que nunca quede una sola tarjeta suelta en la última fila.
      Widget cuadricula(List<Widget> hijos, {double espacio = 14, bool columnasPares = false}) {
        final columnas = columnasPares
            ? (constraints.maxWidth >= 1000 ? 4 : constraints.maxWidth >= 520 ? 2 : 1)
            : porAncho;
        return Column(
            children: [
              for (var i = 0; i < hijos.length; i += columnas)
                Padding(
                  padding: EdgeInsets.only(bottom: espacio),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var c = 0; c < columnas; c++) ...[
                          if (c > 0) SizedBox(width: espacio),
                          Expanded(
                              child: i + c < hijos.length ? hijos[i + c] : const SizedBox.shrink()),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Bienvenida(
            nombre: primerNombre,
            totalMateriales: totalMateriales,
            totalAsignaturas: asignaturas.length,
            compacto: ancho < 720,
            onBuscar: onBuscar,
            onSimulacro: onSimulacro,
          ),
          const TituloSeccion('Cómo te ayuda la IA',
              subtitulo: 'Todo el material pasa por la IA para que estudies mejor.'),
          cuadricula(const [
            _Funcion(Icons.lightbulb_outline, 'Te explica cada material',
                'Resumen, temas en lenguaje sencillo y ejercicios con pista y solución paso a paso.'),
            _Funcion(Icons.quiz_outlined, 'Practicas con quices',
                'Preguntas nuevas sobre cada material, con la explicación de cada respuesta.'),
            _Funcion(Icons.timer_outlined, 'Simulacros de parcial',
                'Un examen de práctica con los temas que más se repiten en tu asignatura.'),
            _Funcion(Icons.verified_user_outlined, 'Material confiable',
                'La IA revisa cada archivo al subirlo: si no es académico o no corresponde, no se publica.'),
          ], columnasPares: true),
          TituloSeccion('Explora por asignatura',
              subtitulo: asignaturas.isEmpty ? null : '${asignaturas.length} asignaturas disponibles'),
          if (asignaturas.isEmpty)
            const Text('Aún no hay asignaturas.', style: TextStyle(color: UtbColores.textoSecundario))
          else
            cuadricula([
              for (final (i, a) in asignaturas.indexed)
                _TarjetaAsignatura(asignatura: a, indice: i, onTap: () => onAsignatura(a)),
            ], espacio: 12),
          const TituloSeccion('Agregado recientemente'),
          if (cargando)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (recientes.isEmpty)
            const Text('Todavía no hay material. ¡Sé el primero en subir uno!',
                style: TextStyle(color: UtbColores.textoSecundario))
          else
            cuadricula([
              for (final m in recientes) MaterialCard(material: m, onTap: () => onAbrir(m)),
            ]),
        ],
      );
    });
  }
}

class _Bienvenida extends StatefulWidget {
  final String nombre;
  final int totalMateriales;
  final int totalAsignaturas;
  final bool compacto;
  final ValueChanged<String> onBuscar;
  final VoidCallback onSimulacro;

  const _Bienvenida({
    required this.nombre,
    required this.totalMateriales,
    required this.totalAsignaturas,
    required this.compacto,
    required this.onBuscar,
    required this.onSimulacro,
  });

  @override
  State<_Bienvenida> createState() => _BienvenidaState();
}

class _BienvenidaState extends State<_Bienvenida> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(widget.compacto ? 22 : 34),
      decoration: BoxDecoration(
        gradient: UtbColores.degradado,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.nombre.isEmpty ? 'Hola' : 'Hola, ${widget.nombre}',
                    style: const TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  '¿Qué vas a estudiar hoy?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: widget.compacto ? 24 : 34,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Busca un parcial y el Tutor IA te lo explica, te hace un quiz y resuelve tus dudas.',
                  style: TextStyle(color: Color(0xE6FFFFFF), height: 1.45),
                ),
                const SizedBox(height: 18),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: TextField(
                    controller: _ctrl,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Ej. «límites», «parcial de SQL», «cinemática»…',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Buscar material',
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () => widget.onBuscar(_ctrl.text.trim()),
                      ),
                    ),
                    onSubmitted: (t) => widget.onBuscar(t.trim()),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: UtbColores.azulOscuro,
                      ),
                      onPressed: widget.onSimulacro,
                      icon: const Icon(Icons.auto_awesome, color: UtbColores.verde),
                      label: const Text('Hacer un simulacro'),
                    ),
                    _Dato('${widget.totalMateriales}', 'materiales'),
                    _Dato('${widget.totalAsignaturas}', 'asignaturas'),
                  ],
                ),
              ],
            ),
          ),
          if (!widget.compacto) ...[
            const SizedBox(width: 30),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 30, offset: Offset(0, 12)),
                ],
              ),
              child: const LogoUtb(altura: 120, soloSimbolo: true),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String valor;
  final String texto;
  const _Dato(this.valor, this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x26FFFFFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text.rich(TextSpan(children: [
        TextSpan(
            text: valor,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
        TextSpan(text: ' $texto', style: const TextStyle(color: Color(0xDDFFFFFF))),
      ])),
    );
  }
}

class _Funcion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  const _Funcion(this.icono, this.titulo, this.texto);

  @override
  Widget build(BuildContext context) {
    return TarjetaUtb(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: UtbColores.verde10,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icono, color: UtbColores.verde),
          ),
          const SizedBox(height: 12),
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 4),
          Text(texto,
              style: const TextStyle(color: UtbColores.textoSecundario, height: 1.45, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TarjetaAsignatura extends StatelessWidget {
  final Asignatura asignatura;
  final int indice;
  final VoidCallback onTap;
  const _TarjetaAsignatura({required this.asignatura, required this.indice, required this.onTap});

  /// Ícono según el área de la asignatura.
  IconData get _icono {
    final n = asignatura.nombre.toLowerCase();
    if (n.contains('cálculo') || n.contains('calculo') || n.contains('matem') || n.contains('álgebra')) {
      return Icons.functions;
    }
    if (n.contains('física') || n.contains('fisica') || n.contains('química')) return Icons.science_outlined;
    if (n.contains('programación') || n.contains('programacion')) return Icons.code;
    if (n.contains('datos')) {
      return n.contains('base') ? Icons.storage_outlined : Icons.account_tree_outlined;
    }
    if (n.contains('software')) return Icons.engineering_outlined;
    return Icons.menu_book_outlined;
  }

  @override
  Widget build(BuildContext context) {
    // Alterna los dos colores institucionales.
    final (color, fondo) =
        indice.isEven ? (UtbColores.azul, UtbColores.azul10) : (UtbColores.verde, UtbColores.verde10);
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: UtbColores.borde),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(14)),
                child: Icon(_icono, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asignatura.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'Semestre ${asignatura.semestre} · '
                      '${asignatura.totalMateriales == 1 ? '1 material' : '${asignatura.totalMateriales} materiales'}',
                      style: const TextStyle(color: UtbColores.textoSecundario, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: UtbColores.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}
