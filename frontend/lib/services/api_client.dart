import 'dart:convert';
import 'package:http/http.dart' as http;

/// Excepción con el mensaje de error que devuelve el Backend API
/// (`{ "error": "..." }`), para mostrarlo directamente en la interfaz.
class ApiException implements Exception {
  final int statusCode;
  final String mensaje;
  ApiException(this.statusCode, this.mensaje);

  @override
  String toString() => mensaje;
}

/// Envoltorio delgado sobre `package:http` que agrega el token de
/// autenticación (RF-02) y traduce respuestas no exitosas en [ApiException].
class ApiClient {
  final String? token;
  ApiClient({this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Map<String, String> get _headersSinContentType => {
        if (token != null) 'Authorization': 'Bearer $token',
      };

  dynamic _procesar(http.Response res) {
    if (res.statusCode == 204) return null;
    final body = res.body.isEmpty ? {} : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final mensaje = (body is Map && body['error'] != null)
        ? body['error'] as String
        : 'Error inesperado (HTTP ${res.statusCode}).';
    throw ApiException(res.statusCode, mensaje);
  }

  Future<dynamic> get(Uri uri) async {
    final res = await http.get(uri, headers: _headers);
    return _procesar(res);
  }

  Future<dynamic> post(Uri uri, Map<String, dynamic> body) async {
    final res = await http.post(uri, headers: _headers, body: jsonEncode(body));
    return _procesar(res);
  }

  Future<dynamic> put(Uri uri, Map<String, dynamic> body) async {
    final res = await http.put(uri, headers: _headers, body: jsonEncode(body));
    return _procesar(res);
  }

  Future<dynamic> patch(Uri uri, Map<String, dynamic> body) async {
    final res = await http.patch(uri, headers: _headers, body: jsonEncode(body));
    return _procesar(res);
  }

  Future<dynamic> delete(Uri uri) async {
    final res = await http.delete(uri, headers: _headers);
    return _procesar(res);
  }

  /// Sube un archivo (multipart/form-data) — usado por RF-06 (carga de material).
  Future<dynamic> postMultipart(
    Uri uri, {
    required Map<String, String> campos,
    required List<int> archivoBytes,
    required String nombreArchivo,
  }) async {
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(_headersSinContentType)
      ..fields.addAll(campos)
      ..files.add(http.MultipartFile.fromBytes('archivo', archivoBytes,
          filename: nombreArchivo));

    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _procesar(res);
  }
}
