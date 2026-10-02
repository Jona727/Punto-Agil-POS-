part of 'auth_bloc.dart';

enum AuthStatus {
  /// Sin sesión y sin haber elegido "probar sin cuenta": debe ir al login.
  unauthenticated,

  /// Sesión iniciada.
  authenticated,

  /// Usa la app solo en este teléfono, sin cuenta.
  guest,
}

class AuthState extends Equatable {
  final AuthStatus status;
  final AppUser? user;
  final bool isLoading;
  final String? error;
  final String? info;
  final bool resetCodeSent;

  const AuthState({
    required this.status,
    this.user,
    this.isLoading = false,
    this.error,
    this.info,
    this.resetCodeSent = false,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    String? info,
    bool? resetCodeSent,
    bool clearMessages = false,
  }) {
    return AuthState(
      status: status,
      user: user,
      isLoading: isLoading ?? this.isLoading,
      error: clearMessages ? null : (error ?? this.error),
      info: clearMessages ? null : (info ?? this.info),
      resetCodeSent: resetCodeSent ?? this.resetCodeSent,
    );
  }

  @override
  List<Object?> get props =>
      [status, user, isLoading, error, info, resetCodeSent];
}
