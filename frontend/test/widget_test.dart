import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:plataforma_apoyo_academico/main.dart';
import 'package:plataforma_apoyo_academico/models/asignatura.dart';
import 'package:plataforma_apoyo_academico/models/material.dart' as modelo;
import 'package:plataforma_apoyo_academico/models/reporte.dart';
import 'package:plataforma_apoyo_academico/models/usuario.dart';
import 'package:plataforma_apoyo_academico/screens/admin_asignaturas_screen.dart';
import 'package:plataforma_apoyo_academico/screens/admin_materiales_screen.dart';
import 'package:plataforma_apoyo_academico/screens/admin_reportes_screen.dart';
import 'package:plataforma_apoyo_academico/screens/admin_usuarios_screen.dart';
import 'package:plataforma_apoyo_academico/screens/home_screen.dart';
import 'package:plataforma_apoyo_academico/screens/material_detail_screen.dart';
import 'package:plataforma_apoyo_academico/screens/simulacro_screen.dart';
import 'package:plataforma_apoyo_academico/state/session.dart';
import 'package:plataforma_apoyo_academico/widgets/material_card.dart';
import 'package:plataforma_apoyo_academico/widgets/tutor_ia_panel.dart';

modelo.Material _material({required String estado, bool anonimo = false}) {
  return modelo.Material.fromJson(_materialJson(estado: estado, anonimo: anonimo));
}

Map<String, dynamic> _materialJson({required String estado, bool anonimo = false}) {
  return {
    'id': 1,
    'titulo': 'Parcial 1 de Cálculo',
    'descripcion': null,
    'archivo_url': '/uploads/parcial.pdf',
    'fecha_publicacion': '2026-09-01T10:00:00.000Z',
    'profesor': 'Ruiz',
    'periodo_academico': '2026-1',
    'es_anonimo': anonimo,
    'estado': estado,
    'asignatura_id': 3,
    'asignatura_nombre': 'Cálculo I',
    'autor_nombre': anonimo ? null : 'Ana',
    'calificacion_promedio': '4.50',
    'total_valoraciones': '2',
    'reportes_pendientes': '0',
  };
}

Widget _envolver(Widget hijo) => MaterialApp(home: Scaffold(body: hijo));

http.Response _json(Object cuerpo, [int estado = 200]) => http.Response(
      jsonEncode(cuerpo),
      estado,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

/// Selector de archivos que devuelve siempre el mismo PDF, sin abrir el diálogo
/// del sistema.
class _SelectorDeArchivoFalso extends FilePicker {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode('%PDF-1.4 prueba'));
    return FilePickerResult([PlatformFile(name: 'quiz.pdf', size: bytes.length, bytes: bytes)]);
  }
}

void main() {
  testWidgets('sin sesión guardada, la app muestra el inicio de sesión (RF-02)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => Session(),
        child: const PlataformaApoyoAcademicoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('¿No tiene cuenta? Regístrese'), findsOneWidget);
  });

  testWidgets('la tarjeta muestra calificación, metadatos y autor (RF-08/RF-11)',
      (tester) async {
    await tester.pumpWidget(_envolver(
      MaterialCard(material: _material(estado: 'publicado'), onTap: () {}),
    ));

    expect(find.text('Parcial 1 de Cálculo'), findsOneWidget);
    expect(find.text('4.5 (2)'), findsOneWidget);
    expect(find.text('Prof. Ruiz · 2026-1'), findsOneWidget);
    expect(find.text('Ana'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
  });

  testWidgets('el material anónimo no muestra a su autor (RF-07)', (tester) async {
    await tester.pumpWidget(_envolver(
      MaterialCard(material: _material(estado: 'publicado', anonimo: true), onTap: () {}),
    ));
    expect(find.text('Anónimo'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);
  });

  testWidgets('el material reportado o retirado muestra su indicador (RNF-05)',
      (tester) async {
    await tester.pumpWidget(_envolver(
      MaterialCard(material: _material(estado: 'reportado'), onTap: () {}),
    ));
    expect(find.text('En revisión'), findsOneWidget);

    await tester.pumpWidget(_envolver(
      MaterialCard(material: _material(estado: 'retirado'), onTap: () {}),
    ));
    expect(find.text('Retirado'), findsOneWidget);
  });

  test('«reportado» y «en_revision» se llaman igual en la lista y en la ficha (H-07)', () {
    expect(_material(estado: 'publicado').estadoVisible, 'Publicado');
    expect(_material(estado: 'reportado').estadoVisible, 'En revisión');
    expect(_material(estado: 'en_revision').estadoVisible, 'En revisión');
    expect(_material(estado: 'retirado').estadoVisible, 'Retirado');
  });

  testWidgets('«Reportar» se activa solo con un motivo y lo envía sin espacios (H-03)',
      (tester) async {
    String? motivo = 'sin respuesta';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            motivo = await showDialog<String>(
                context: context, builder: (_) => const DialogoReportar());
          },
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    FilledButton boton() =>
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Reportar'));
    expect(boton().onPressed, isNull);
    expect(find.text('Escriba el motivo para enviar el reporte.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(boton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  El profesor es distinto ');
    await tester.pump();
    expect(boton().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Reportar'));
    await tester.pumpAndSettle();
    expect(motivo, 'El profesor es distinto');
  });

  testWidgets('el formulario de carga muestra primero el interruptor anónimo y los '
      'archivos permitidos (H-05/H-06)', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_envolver(const DialogoSubirMaterial(
      asignaturas: [Asignatura(id: 1, nombre: 'Cálculo I', codigo: 'MAT101', semestre: '1')],
      token: null,
    )));

    final interruptor = tester.getTopLeft(find.text('Subir de forma anónima'));
    final titulo = tester.getTopLeft(find.widgetWithText(TextFormField, 'Título'));
    expect(interruptor.dy, lessThan(titulo.dy));
    expect(find.text(textoArchivosPermitidos), findsOneWidget);
  });

  test('el archivo se revisa antes de subirlo (H-06, regla R-02)', () {
    expect(validarArchivo('parcial.PDF', 1024), isNull);
    expect(validarArchivo('foto.jpeg', tamanoMaximoArchivo), isNull);
    expect(validarArchivo('programa.exe', 1024), contains('no permitido'));
    expect(validarArchivo('sin-extension', 1024), contains('no permitido'));
    expect(validarArchivo('apuntes.zip', tamanoMaximoArchivo + 1), contains('25 MB'));
  });

  testWidgets('al subir material se confirma la carga y se quitan los filtros (H-04)',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final busquedas = <Map<String, String>>[];
    final api = MockClient((request) async {
      final ruta = request.url.path;
      if (request.method == 'GET' && ruta == '/api/asignaturas') {
        return _json([
          {'id': 3, 'nombre': 'Cálculo I', 'codigo': 'MAT101', 'semestre': '1', 'activo': true},
        ]);
      }
      if (request.method == 'GET' && ruta == '/api/materiales') {
        busquedas.add(request.url.queryParameters);
        return _json([_materialJson(estado: 'publicado')]);
      }
      if (request.method == 'POST' && ruta == '/api/materiales') {
        return _json({..._materialJson(estado: 'publicado', anonimo: true), 'id': 2}, 201);
      }
      return _json({'error': 'Ruta no esperada: ${request.method} $ruta'}, 404);
    });
    FilePicker.platform = _SelectorDeArchivoFalso();

    await http.runWithClient(() async {
      SharedPreferences.setMockInitialValues({});
      final session = Session();
      await session.iniciar(
        const Usuario(id: 5, nombre: '001', correo: 'estudiante@prueba.com', rol: 'estudiante'),
        'token-de-prueba',
      );
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: session,
        child: const MaterialApp(home: HomeScreen()),
      ));
      await tester.pumpAndSettle();

      // El estudiante tenía un texto buscado antes de subir el material.
      await tester.enterText(find.byType(TextField).first, 'parcial');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(busquedas.last['q'], 'parcial');

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      final dialogo = find.byType(DialogoSubirMaterial);
      await tester.tap(find.descendant(of: dialogo, matching: find.byType(Switch)));
      await tester.enterText(
          find.descendant(of: dialogo, matching: find.widgetWithText(TextFormField, 'Título')),
          'Quiz 2 de límites');
      await tester.tap(find.descendant(
          of: dialogo, matching: find.byType(DropdownButtonFormField<Asignatura>)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cálculo I (MAT101 · 1)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elegir archivo'));
      await tester.pumpAndSettle();
      expect(find.text('quiz.pdf'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Subir'));
      await tester.pumpAndSettle();

      expect(find.byType(DialogoSubirMaterial), findsNothing);
      expect(find.text('Material publicado de forma anónima.'), findsOneWidget);
      expect(find.widgetWithText(SnackBarAction, 'Ver'), findsOneWidget);
      // La lista se vuelve a cargar sin filtros, con el material nuevo primero.
      expect(busquedas.last, isEmpty);
      expect(find.text('parcial'), findsNothing);

      // Se deja que el aviso se cierre para no dejar temporizadores pendientes.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }, () => api);
  });

  // En las pruebas de Flutter las peticiones HTTP reales se bloquean (responden
  // 400), así que estas pantallas muestran su mensaje de error: lo que se
  // verifica es que se dibujen sin desbordes ni excepciones.
  Future<Session> sesionAdministrador() async {
    SharedPreferences.setMockInitialValues({});
    final session = Session();
    await session.iniciar(
      const Usuario(id: 1, nombre: 'Admin', correo: 'admin@uni.edu.co', rol: 'administrador'),
      'token-de-prueba',
    );
    return session;
  }

  testWidgets('la pantalla principal cabe en un navegador móvil (RNF-03) y el '
      'administrador ve su menú (RF-10/12/13)', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final session = await sesionAdministrador();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: session,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();

    // En el celular, la navegación va en la barra inferior.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Subir material'), findsOneWidget);
    await tester.tap(find.text('Explorar'));
    await tester.pumpAndSettle();
    expect(find.text('Semestre'), findsOneWidget);
    expect(find.text('Asignatura'), findsOneWidget);

    await tester.tap(find.byTooltip('Administración'));
    await tester.pumpAndSettle();
    for (final opcion in ['Gestionar material', 'Revisar reportes', 'Asignaturas', 'Usuarios']) {
      expect(find.text(opcion), findsOneWidget);
    }
  });

  testWidgets('en escritorio el menú de administración muestra su nombre', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final session = await sesionAdministrador();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: session,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Administración'));
    await tester.pumpAndSettle();
    expect(find.text('Revisar reportes'), findsOneWidget);
  });

  for (final (nombre, pantalla) in [
    ('material', const AdminMaterialesScreen()),
    ('reportes', const AdminReportesScreen()),
    ('asignaturas', const AdminAsignaturasScreen()),
    ('usuarios', const AdminUsuariosScreen()),
  ]) {
    testWidgets('la pantalla de administración de $nombre se dibuja en móvil', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final session = await sesionAdministrador();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: session,
        child: MaterialApp(home: pantalla),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
    });
  }

  test('el reporte muestra su fecha en la hora local (RF-09)', () {
    final r = Reporte.fromJson({
      'id': 1,
      'motivo': 'El profesor del quiz es distinto',
      'estado': 'pendiente',
      'material_id': 4,
      'material_titulo': 'Quiz de cinemática',
      'reportado_por': '001',
      'creado_en': '2026-10-22T13:48:32.000Z',
    });
    final local = DateTime.utc(2026, 10, 22, 13, 48, 32).toLocal();
    final esperado = '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    expect(fechaDeReporte(r.creadoEn), esperado);
  });

  // ------------------------------------------------------------ Tutor IA

  /// API falsa del Tutor IA: responde según la ruta y guarda los cuerpos enviados.
  MockClient apiTutor({required bool disponible, List<Map<String, dynamic>>? enviados}) {
    return MockClient((request) async {
      final ruta = request.url.path;
      if (request.body.isNotEmpty) enviados?.add(jsonDecode(request.body));
      if (ruta == '/api/ia/estado') {
        return _json({'disponible': disponible, 'modelo': 'claude-opus-5-5', 'limite_por_hora': 20});
      }
      if (ruta == '/api/materiales/1/ia/explicacion') {
        return _json({
          'fuente': 'archivo',
          'guardado': false,
          'contenido': {
            'resumen': 'Parcial de límites y continuidad.',
            'temas': [
              {'nombre': 'Límites notables', 'explicacion': 'Son límites que conviene memorizar.', 'ejemplo': 'lim x→0 sen(x)/x = 1'},
            ],
            'ejercicios': [
              {'enunciado': 'Calcule lim x→2 (x^2 - 4)/(x - 2)', 'pista': 'Factorice el numerador.', 'solucion': 'Se simplifica a x + 2, así que el límite es 4.'},
            ],
            'consejos': ['Practique la factorización.'],
          },
        }, 201);
      }
      if (ruta == '/api/materiales/1/ia/practica') {
        return _json({
          'fuente': 'metadatos',
          'guardado': true,
          'contenido': {
            'preguntas': [
              {'enunciado': '¿Cuánto es lim x→0 sen(x)/x?', 'opciones': ['0', '1', '∞', 'No existe'], 'correcta': 1, 'explicacion': 'Es un límite notable.'},
            ],
          },
        });
      }
      if (ruta == '/api/materiales/1/ia/preguntas') {
        final pregunta = jsonDecode(request.body)['pregunta'];
        return _json({'fuente': 'archivo', 'respuesta': 'Respuesta del tutor a: $pregunta'});
      }
      return _json({'error': 'Ruta no esperada: ${request.method} $ruta'}, 404);
    });
  }

  Widget panelTutor() => const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: TutorIaPanel(materialId: 1, token: 'token')),
        ),
      );

  testWidgets('RF-14: sin clave de IA en el servidor, el Tutor IA lo explica', (tester) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(panelTutor());
      await tester.pumpAndSettle();
      expect(find.text('El Tutor IA no está configurado en este servidor'), findsOneWidget);
      expect(find.text('Explicar este material'), findsNothing);
    }, () => apiTutor(disponible: false));
  });

  testWidgets('RF-14: el Tutor IA explica el material y oculta la solución hasta pedirla',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await http.runWithClient(() async {
      await tester.pumpWidget(panelTutor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explicar este material'));
      await tester.pumpAndSettle();

      expect(find.text('Parcial de límites y continuidad.'), findsOneWidget);
      expect(find.text('Límites notables'), findsOneWidget);
      expect(find.text('Calcule lim x→2 (x^2 - 4)/(x - 2)'), findsOneWidget);
      expect(find.text('Se simplifica a x + 2, así que el límite es 4.'), findsNothing);

      await tester.tap(find.text('Ver solución'));
      await tester.pumpAndSettle();
      expect(find.text('Se simplifica a x + 2, así que el límite es 4.'), findsOneWidget);
      expect(find.textContaining('Generado con IA'), findsOneWidget);
    }, () => apiTutor(disponible: true));
  });

  testWidgets('RF-15: el quiz marca la respuesta y muestra la explicación', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await http.runWithClient(() async {
      await tester.pumpWidget(panelTutor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Practicar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generar quiz'));
      await tester.pumpAndSettle();

      // R-12: la IA solo vio el título y la descripción, y la app lo avisa.
      expect(find.text('La IA no pudo leer el archivo'), findsOneWidget);
      expect(find.text('Respondidas: 0 de 1 · Correctas: 0'), findsOneWidget);
      await tester.tap(find.text('0'));
      await tester.pumpAndSettle();
      expect(find.text('Incorrecto'), findsOneWidget);
      expect(find.text('Es un límite notable.'), findsOneWidget);
      expect(find.text('Respondidas: 1 de 1 · Correctas: 0'), findsOneWidget);
      // Una pregunta respondida ya no cambia.
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();
      expect(find.text('Respondidas: 1 de 1 · Correctas: 0'), findsOneWidget);
    }, () => apiTutor(disponible: true));
  });

  testWidgets('RF-16: el chat envía la pregunta con el historial de la conversación',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final enviados = <Map<String, dynamic>>[];

    await http.runWithClient(() async {
      await tester.pumpWidget(panelTutor());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Preguntar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text(sugerenciasTutor.first));
      await tester.pumpAndSettle();
      expect(find.text('Respuesta del tutor a: ${sugerenciasTutor.first}'), findsOneWidget);
      expect(enviados.last['historial'], isEmpty);

      await tester.enterText(find.byType(TextField), '¿Y el punto 2?');
      await tester.tap(find.byTooltip('Enviar pregunta'));
      await tester.pumpAndSettle();
      expect(find.text('Respuesta del tutor a: ¿Y el punto 2?'), findsOneWidget);
      expect(enviados.last['pregunta'], '¿Y el punto 2?');
      expect(enviados.last['historial'], [
        {'rol': 'estudiante', 'texto': sugerenciasTutor.first},
        {'rol': 'tutor', 'texto': 'Respuesta del tutor a: ${sugerenciasTutor.first}'},
      ]);
    }, () => apiTutor(disponible: true, enviados: enviados));
  });

  testWidgets('RNF-03: la ficha del material con el Tutor IA cabe en un celular', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 740 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final api = MockClient((request) async {
      final ruta = request.url.path;
      if (ruta == '/api/materiales/1') return _json(_materialJson(estado: 'publicado'));
      if (ruta == '/api/materiales/1/valoraciones') return _json([]);
      if (ruta == '/api/ia/estado') return _json({'disponible': true, 'limite_por_hora': 20});
      return _json({'error': 'Ruta no esperada'}, 404);
    });

    await http.runWithClient(() async {
      final session = await sesionAdministrador();
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: session,
        child: const MaterialApp(home: MaterialDetailScreen(materialId: 1)),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Descargar'), findsOneWidget);
      expect(find.text('Tutor IA'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Explicar este material'), 200);
      expect(find.text('Explicar este material'), findsOneWidget);
    }, () => api);
  });

  testWidgets('en escritorio, el inicio de sesión muestra el panel de la UTB', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => Session(),
      child: const PlataformaApoyoAcademicoApp(),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Plataforma de\nApoyo Académico'), findsOneWidget);
    expect(find.text('Tutor IA'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });

  // ------------------------------------------------------------ RF-17 a RF-19

  Map<String, dynamic> revisionJson({String veredicto = 'aprobado', Map<String, bool>? criterios}) => {
        'veredicto': veredicto,
        'motivo': veredicto == 'rechazado'
            ? 'Es una guía de química, no de Cálculo I.'
            : 'Parcial de límites con soluciones.',
        'tipo': 'parcial',
        'temas': ['Límites', 'Continuidad'],
        'dificultad': 'media',
        'resumen': 'Cinco ejercicios resueltos.',
        'criterios': criterios ??
            {
              'es_material_academico': true,
              'coincide_con_asignatura': veredicto != 'rechazado',
              'coincide_con_titulo': true,
              'legible': true,
              'contenido_inapropiado': false,
              'datos_personales': false,
            },
      };

  /// Abre el diálogo de carga, completa el formulario y pulsa «Subir».
  Future<void> subirConDialogo(WidgetTester tester, MockClient api) async {
    tester.view.physicalSize = const Size(1280, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    FilePicker.platform = _SelectorDeArchivoFalso();
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showDialog<modelo.Material>(
            context: context,
            builder: (_) => const DialogoSubirMaterial(
              asignaturas: [Asignatura(id: 3, nombre: 'Cálculo I', codigo: 'MAT101', semestre: '1')],
              token: 'token',
            ),
          ),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Título'), 'Guía 1');
    await tester.tap(find.byType(DropdownButtonFormField<Asignatura>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cálculo I (MAT101 · 1)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elegir archivo'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Subir'));
    await tester.pumpAndSettle();
  }

  testWidgets('RF-17: si la IA rechaza el material, se ve el motivo y se puede corregir',
      (tester) async {
    final api = MockClient((request) async => _json({
          'error': 'La IA no aprobó el material: Es una guía de química, no de Cálculo I.',
          'revision': revisionJson(veredicto: 'rechazado'),
        }, 422));
    await http.runWithClient(() async {
      await subirConDialogo(tester, api);
      expect(find.text('La IA no aprobó el material'), findsOneWidget);
      expect(find.text('Es una guía de química, no de Cálculo I.'), findsOneWidget);
      expect(find.text('Corresponde a la asignatura'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget); // el criterio que falló

      await tester.tap(find.text('Corregir y reintentar'));
      await tester.pumpAndSettle();
      // Vuelve al formulario con los datos que ya había escrito.
      expect(find.text('Guía 1'), findsOneWidget);
      expect(find.text('quiz.pdf'), findsOneWidget);
    }, () => api);
  });

  testWidgets('RF-17/RF-19: si la IA aprueba, se ve la vista previa y lo que identificó',
      (tester) async {
    final api = MockClient((request) async => _json({
          ..._materialJson(estado: 'publicado'),
          'miniatura_url': null,
          'revision_ia': revisionJson(),
        }, 201));
    await http.runWithClient(() async {
      await subirConDialogo(tester, api);
      expect(find.text('¡Material publicado!'), findsOneWidget);
      expect(find.text('Parcial'), findsOneWidget);
      expect(find.text('Dificultad media'), findsOneWidget);
      expect(find.text('Límites'), findsOneWidget);
      await tester.tap(find.text('Listo'));
      await tester.pumpAndSettle();
      expect(find.byType(DialogoSubirMaterial), findsNothing);
    }, () => api);
  });

  testWidgets('RF-17: la tarjeta muestra el tipo, los temas y «Verificado por IA»', (tester) async {
    final material = modelo.Material.fromJson({
      ..._materialJson(estado: 'publicado'),
      'revision_ia': revisionJson(),
    });
    await tester.pumpWidget(_envolver(SizedBox(
      width: 360,
      child: MaterialCard(material: material, onTap: () {}),
    )));
    expect(find.text('Verificado por IA'), findsOneWidget);
    expect(find.text('Parcial'), findsOneWidget);
    expect(find.text('Continuidad'), findsOneWidget);
    expect(material.revisionIa!.tipoVisible, 'Parcial');
    expect(material.estadoVisible, 'Publicado');
    expect(_material(estado: 'pendiente').estadoVisible, 'Pendiente de revisión');
  });

  testWidgets('RF-18: el simulacro muestra la nota y los temas para repasar', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = MockClient((request) async {
      if (request.url.path == '/api/ia/estado') return _json({'disponible': true, 'limite_por_hora': 20});
      return _json({
        'materiales_usados': 2,
        'contenido': {
          'preguntas': [
            {'enunciado': '¿Derivada de x²?', 'opciones': ['x', '2x', 'x²', '2'], 'correcta': 1, 'explicacion': 'Regla de la potencia.', 'tema': 'Derivadas'},
          ],
        },
      });
    });
    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SimulacroPagina(
              asignaturas: [
                Asignatura(id: 3, nombre: 'Cálculo I', codigo: 'MAT101', semestre: '1', totalMateriales: 2),
                Asignatura(id: 4, nombre: 'Sin material', codigo: 'X', semestre: '1'),
              ],
              token: 'token',
              inicial: Asignatura(id: 3, nombre: 'Cálculo I', codigo: 'MAT101', semestre: '1', totalMateriales: 2),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generar simulacro'));
      await tester.pumpAndSettle();
      expect(find.text('¿Derivada de x²?'), findsOneWidget);
      await tester.tap(find.text('x').last); // respuesta incorrecta
      await tester.pumpAndSettle();
      expect(find.text('0.0'), findsOneWidget);
      expect(find.text('Temas para repasar:'), findsOneWidget);
      expect(find.text('Derivadas'), findsWidgets);
    }, () => api);
  });

  testWidgets('en computador, la barra lateral muestra las secciones y la administración',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = await sesionAdministrador();
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: session,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();
    for (final texto in ['Inicio', 'Explorar', 'Simulacro IA', 'Mis aportes', 'Usuarios']) {
      expect(find.text(texto), findsOneWidget, reason: texto);
    }
    expect(find.text('¿Qué vas a estudiar hoy?'), findsOneWidget);
    await tester.tap(find.text('Mis aportes'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo aporte'), findsOneWidget);
  });

  test('el tipo de archivo se reconoce por su extensión', () {
    expect(tipoDeArchivo('/uploads/1.PDF').$2, 'PDF');
    expect(tipoDeArchivo('/uploads/foto.jpeg').$2, 'Imagen');
    expect(tipoDeArchivo('/uploads/taller.docx').$2, 'Word');
    expect(tipoDeArchivo('/uploads/x.zip').$2, 'ZIP');
  });

  test('dos asignaturas con el mismo id son iguales (filtros del buscador)', () {
    const a = Asignatura(id: 1, nombre: 'Cálculo I', codigo: 'MAT101', semestre: '1');
    final b = Asignatura.fromJson(
        {'id': 1, 'nombre': 'Cálculo I', 'codigo': 'MAT101', 'semestre': '1', 'activo': false});
    expect(a, equals(b));
    expect(b.activo, isFalse);
  });
}
