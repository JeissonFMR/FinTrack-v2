/// Configuración central de URLs del backend.
///
/// Para builds de producción, pasa la URL así:
///
///   flutter run --dart-define=API_BASE_URL=https://api.tudominio.com/api/v1
///   flutter build apk --dart-define=API_BASE_URL=https://api.tudominio.com/api/v1
///
/// Si no pasas nada, usa el default (emulador Android local).
class ApiConfig {
  ApiConfig._();

  /// URL base de la API. Sobrescríbela en build/run con --dart-define.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://31.220.103.76:4000/api/v1',
  );
}
