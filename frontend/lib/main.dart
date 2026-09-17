import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'state/session.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => Session(),
      child: const PlataformaApoyoAcademicoApp(),
    ),
  );
}

class PlataformaApoyoAcademicoApp extends StatelessWidget {
  const PlataformaApoyoAcademicoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plataforma de Apoyo Académico',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2A78D6),
        useMaterial3: true,
      ),
      home: const _ArranqueSesion(),
    );
  }
}

/// Al abrir la app, intenta recuperar un token guardado (ver [Session]) antes
/// de decidir si muestra el login o la pantalla principal.
class _ArranqueSesion extends StatefulWidget {
  const _ArranqueSesion();

  @override
  State<_ArranqueSesion> createState() => _ArranqueSesionState();
}

class _ArranqueSesionState extends State<_ArranqueSesion> {
  bool _verificando = true;

  @override
  void initState() {
    super.initState();
    _recuperarSesion();
  }

  Future<void> _recuperarSesion() async {
    final session = context.read<Session>();
    final token = await session.tokenGuardado();

    if (token != null) {
      try {
        final usuario = await AuthService().perfil(token);
        await session.iniciar(usuario, token);
      } catch (_) {
        // Token vencido o inválido: se ignora y se pide iniciar sesión de nuevo.
      }
    }

    if (mounted) setState(() => _verificando = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_verificando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final autenticado = context.watch<Session>().autenticado;
    return autenticado ? const HomeScreen() : const LoginScreen();
  }
}
