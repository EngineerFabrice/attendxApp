import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/storage/secure_storage.dart';
import '../domain/user_model.dart';

class AuthRepository {
  final Dio _dio = ApiClient().dio;
  final SecureStorage _storage = SecureStorage();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final fingerprint = await _storage.getOrCreateDeviceFingerprint();
    
    final response = await _dio.post(ApiEndpoints.login, data: {
      'email': email,
      'password': password,
      'deviceFingerprint': fingerprint,
    });
    
    return response.data['data'];
  }

  Future<void> saveUserData(
    UserModel user, String accessToken, String refreshToken) async {
    await _storage.saveTokens(accessToken, refreshToken);
    await _storage.saveUser(user.toJsonString());
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    final response = await _dio.post(ApiEndpoints.forgotPassword,
        data: {'email': email});
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await _dio.post(ApiEndpoints.resetPassword,
        data: {'token': token, 'newPassword': newPassword});
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiEndpoints.logout);
    } catch (_) {}
    await _storage.clearTokens();
  }

  Future<String?> getAccessToken() async {
    return _storage.getAccessToken();
  }

  Future<UserModel?> getCurrentUser() async {
    final token = await _storage.getAccessToken();
    if (token == null) return null;
    final userJson = await _storage.getUser();
    if (userJson == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}