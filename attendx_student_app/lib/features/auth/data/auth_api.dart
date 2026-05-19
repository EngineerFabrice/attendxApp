import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class AuthApi {
  final Dio _dio = ApiClient().dio;

  Future<Response> login(Map<String, dynamic> data) {
    return _dio.post(ApiEndpoints.login, data: data);
  }

  Future<Response> logout() {
    return _dio.post(ApiEndpoints.logout);
  }

  Future<Response> forgotPassword(String email) {
    return _dio.post(ApiEndpoints.forgotPassword, data: {'email': email});
  }

  Future<Response> resetPassword(String token, String newPassword) {
    return _dio.post(ApiEndpoints.resetPassword,
        data: {'token': token, 'newPassword': newPassword});
  }
}
