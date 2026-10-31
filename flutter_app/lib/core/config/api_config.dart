class ApiConfig {
  // Android emulator reaches the development PC through 10.0.2.2.
  // Use --dart-define=API_BASE_URL=... for a phone or another server.
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
