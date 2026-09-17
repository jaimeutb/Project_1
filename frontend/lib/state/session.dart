import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';

/// Guarda el usuario autenticado y su token JWT (RF-02) durante la sesión,
/// y los persiste en el navegador (shared_preferences) para sobrevivir a
/// una recarga de página.
class Session extends ChangeNotifier {
  Usuario? _usuario;
  String? _token;

  Usuario? get usuario => _usuario;
  String? get token => _token;
  bool get autenticado => _token != null;
  bool get esAdministrador => _usuario?.esAdministrador ?? false;

  Future<void> iniciar(Usuario usuario, String token) async {
    _usuario = usuario;
    _token = token;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  Future<void> cerrarSesion() async {
    _usuario = null;
    _token = null;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  Future<String?> tokenGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
}
