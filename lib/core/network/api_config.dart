abstract final class ApiConfig {
  // localhost works only when Flutter runs on the same machine as the backend.
  // Android emulators usually need 10.0.2.2, and real devices need the host
  // computer's LAN IP, for example http://192.168.x.x:5000.
  static const String baseUrl = 'http://localhost:5000';
}
