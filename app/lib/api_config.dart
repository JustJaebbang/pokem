// Override per device/environment with:
// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://192.168.10.36:8000',
);
