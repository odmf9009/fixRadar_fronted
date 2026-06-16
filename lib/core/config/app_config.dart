import 'secrets.dart';

class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://app.fixesradar.com/api',
  );

  static String get googleMapsApiKey =>
      const String.fromEnvironment('GOOGLE_MAPS_KEY').isNotEmpty
          ? const String.fromEnvironment('GOOGLE_MAPS_KEY')
          : Secrets.googleMapsApiKey;

  static String get geminiApiKey =>
      const String.fromEnvironment('GEMINI_KEY').isNotEmpty
          ? const String.fromEnvironment('GEMINI_KEY')
          : Secrets.geminiApiKey;

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://app.fixesradar.com',
  );

  static const double defaultSearchRadius = 30.0;
  static const double maxSearchRadius = 80.0;
}
