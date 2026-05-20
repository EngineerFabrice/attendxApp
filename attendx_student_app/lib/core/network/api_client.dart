import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  /// Base URL is injected at build time via --dart-define=API_BASE_URL=...
  ///
  /// Build commands:
  ///   Emulator : flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
  ///   Device   : flutter run --dart-define=API_BASE_URL=http://192.168.x.x:5000/api
  ///   Release  : flutter build apk --dart-define=API_BASE_URL=https://api.attendx.ac.rw/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',  // Android emulator default
  );

  late Dio _dio;
  final SecureStorage _storage = SecureStorage();

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    // Inject JWT Bearer token on every request
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (err, handler) {
        // 401 handled per-feature (auth_provider clears storage)
        handler.next(err);
      },
    ));
  }

  Dio get dio => _dio;
}
