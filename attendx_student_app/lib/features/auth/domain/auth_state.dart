import 'package:equatable/equatable.dart';
import 'user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();
  
  bool get isAuthenticated => false;
  UserModel? get user => null;
  
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final UserModel _user;
  
  const AuthAuthenticated(this._user);
  
  @override
  bool get isAuthenticated => true;
  
  @override
  UserModel? get user => _user;
  
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// Emitted after forgotPassword succeeds — carries the reset token (dev only)
class AuthForgotPasswordSent extends AuthState {
  final String? devResetToken;
  const AuthForgotPasswordSent({this.devResetToken});

  @override
  List<Object?> get props => [devResetToken];
}

// Emitted after resetPassword succeeds
class AuthPasswordResetSuccess extends AuthState {
  const AuthPasswordResetSuccess();
}