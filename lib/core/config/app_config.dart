class AppConfig {
  // Change this to your deployed backend URL in production
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://2.24.77.82:3002/api',
  );

  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_KEY',
    defaultValue: 'YOUR_GOOGLE_MAPS_API_KEY',
  );

  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_KEY',
    defaultValue: 'YOUR_GEMINI_API_KEY',
  );

  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'http://2.24.77.82:3002',
  );

  static const double defaultSearchRadius = 30.0; // km
  static const double maxSearchRadius = 80.0; // km
}
