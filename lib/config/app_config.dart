/// Configuración de la app que se puede definir en tiempo de compilación.
///
/// Usar con --dart-define al compilar:
/// ```
/// flutter build apk \
///   --dart-define=XTREAM_URL=http://tu-servidor.com \
///   --dart-define=XTREAM_USER=tu_usuario \
///   --dart-define=XTREAM_PASS=tu_password
/// ```
class AppConfig {
  // Valores por defecto desde --dart-define (vacíos si no se proporcionan)
  static const String defaultUrl = String.fromEnvironment('XTREAM_URL');
  static const String defaultUser = String.fromEnvironment('XTREAM_USER');
  static const String defaultPass = String.fromEnvironment('XTREAM_PASS');

  /// Retorna true si hay credenciales configuradas en el build
  static bool get hasDefaultCredentials =>
      defaultUrl.isNotEmpty && defaultUser.isNotEmpty && defaultPass.isNotEmpty;
}
