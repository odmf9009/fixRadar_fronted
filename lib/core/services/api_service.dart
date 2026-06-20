import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  late final Dio _dio;

  void init() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      logPrint: (obj) => print('[DIO] $obj'),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Google login → Firebase ID token
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          final token = await firebaseUser.getIdToken();
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          // Email/backend login → stored JWT
          final prefs = await SharedPreferences.getInstance();
          final backendToken = prefs.getString('backend_jwt');
          if (backendToken != null) {
            options.headers['Authorization'] = 'Bearer $backendToken';
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('backend_jwt');
          FirebaseAuth.instance.signOut();
        }

        if (error.response?.statusCode == 429) {
          print('[API] Rate limit exceeded (429)');
          // Silently skip if it's a polling background request to avoid annoying the user
          // But we log it for debugging.
        }

        handler.next(error);
      },
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> delete(String path) =>
      _dio.delete(path);
}
