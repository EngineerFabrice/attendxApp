import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/user_model.dart';
import '../../domain/auth_state.dart';
import '../../../../core/services/socket_service.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  final _repository = AuthRepository();

  AuthNotifier() : super(const AuthInitial());

  Future<void> login(String email, String password) async {
    state = const AuthLoading();
    try {
      final data = await _repository.login(email, password);
      final user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
      final tokens = data['tokens'] as Map<String, dynamic>;
      final accessToken = tokens['accessToken'] as String;
      final refreshToken = tokens['refreshToken'] as String;

      await _repository.saveUserData(user, accessToken, refreshToken);

      // Connect real-time socket after successful auth
      SocketService().connect(accessToken);

      // Register FCM token so backend can push notifications to this device
      _registerFcmToken();

      state = AuthAuthenticated(user);
    } catch (e) {
      state = const AuthError('Login failed. Please check your credentials.');
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _repository.registerDeviceToken(token);
    } catch (_) {}
  }

  Future<void> logout() async {
    state = const AuthLoading();
    SocketService().disconnect();
    await _repository.logout();
    state = const AuthUnauthenticated();
  }

  Future<void> forgotPassword(String email) async {
    state = const AuthLoading();
    try {
      final data = await _repository.forgotPassword(email);
      final devToken = data['resetToken'] as String?;
      state = AuthForgotPasswordSent(devResetToken: devToken);
    } catch (_) {
      state = const AuthError('Failed to send reset code. Please try again.');
    }
  }

  Future<void> resetPassword(String token, String newPassword) async {
    state = const AuthLoading();
    try {
      await _repository.resetPassword(token, newPassword);
      state = const AuthPasswordResetSuccess();
    } catch (_) {
      state = const AuthError('Invalid or expired reset code. Please try again.');
    }
  }

  void clearError() {
    if (state is AuthError) state = const AuthUnauthenticated();
  }

  Future<void> checkAuthStatus() async {
    state = const AuthLoading();
    final user = await _repository.getCurrentUser();
    if (user != null) {
      final token = await _repository.getAccessToken();
      if (token != null) SocketService().connect(token);
      state = AuthAuthenticated(user);
    } else {
      state = const AuthUnauthenticated();
    }
  }
}
