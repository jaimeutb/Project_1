/// Configuración del cliente HTTP hacia el Backend API.
///
/// En desarrollo, el backend corre en http://localhost:4000 (ver
/// backend/.env.example). Para producción, cambie [baseUrl] o inyéctelo
/// con --dart-define=API_BASE_URL=https://su-backend.example.com al compilar
/// (flutter build web --dart-define=API_BASE_URL=...).
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:4000',
  );

  static Uri api(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl/api$path').replace(queryParameters: query);
  }

  static Uri archivo(String rutaRelativa) {
    // rutaRelativa llega como "/uploads/archivo.pdf" desde el backend.
    return Uri.parse('$baseUrl$rutaRelativa');
  }
}
