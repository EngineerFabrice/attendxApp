import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userKey = 'user';
  static const String _deviceFingerprintKey = 'device_fingerprint';
  static const String _biometricsEnabledKey = 'biometrics_enabled';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userKey);
  }

  Future<void> saveUser(String userJson) async {
    await _storage.write(key: _userKey, value: userJson);
  }

  Future<String?> getUser() async {
    return await _storage.read(key: _userKey);
  }

  Future<bool> getBiometricsEnabled() async {
    final val = await _storage.read(key: _biometricsEnabledKey);
    return val == 'true';
  }

  Future<void> setBiometricsEnabled(bool value) async {
    await _storage.write(
        key: _biometricsEnabledKey, value: value ? 'true' : 'false');
  }

  Future<String> getOrCreateDeviceFingerprint() async {
    final existing = await _storage.read(key: _deviceFingerprintKey);
    if (existing != null) return existing;
    
    // Generate simple fingerprint
    final fingerprint = DateTime.now().millisecondsSinceEpoch.toString();
    await _storage.write(key: _deviceFingerprintKey, value: fingerprint);
    return fingerprint;
  }
}