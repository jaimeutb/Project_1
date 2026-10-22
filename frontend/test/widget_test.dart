import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:plataforma_apoyo_academico/state/session.dart';
import 'package:plataforma_apoyo_academico/widgets/material_card.dart';

modelo.Material _material({required String estado, bool anonimo = false}) {
  return modelo.Material.fromJson({
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
  });
}

Widget _envolver(Widget hijo) => MaterialApp(home: Scaffold(body: hijo));

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

    expect(find.text('Semestre'), findsOneWidget);
    expect(find.text('Asignatura'), findsOneWidget);
    expect(find.text('Subir material'), findsOneWidget);

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

  test('dos asignaturas con el mismo id son iguales (filtros del buscador)', () {
    const a = Asignatura(id: 1, nombre: 'Cálculo I', codigo: 'MAT101', semestre: '1');
    final b = Asignatura.fromJson(
        {'id': 1, 'nombre': 'Cálculo I', 'codigo': 'MAT101', 'semestre': '1', 'activo': false});
    expect(a, equals(b));
    expect(b.activo, isFalse);
  });
}
