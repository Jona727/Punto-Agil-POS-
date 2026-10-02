part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthUserChanged extends AuthEvent {
  final AppUser? user;
  const AuthUserChanged(this.user);
  @override
  List<Object?> get props => [user];
}

class AuthSignInRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthSignInRequested(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpRequested extends AuthEvent {
  final String email;
  final String password;
  const AuthSignUpRequested(this.email, this.password);
  @override
  List<Object?> get props => [email, password];
}

/// Cierra la sesión, o sale del modo sin cuenta para poder ingresar/registrarse.
class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}

class AuthGuestRequested extends AuthEvent {
  const AuthGuestRequested();
}

class AuthPasswordResetRequested extends AuthEvent {
  final String email;
  const AuthPasswordResetRequested(this.email);
  @override
  List<Object?> get props => [email];
}

class AuthPasswordResetConfirmed extends AuthEvent {
  final String email;
  final String code;
  final String newPassword;
  const AuthPasswordResetConfirmed(
      {required this.email, required this.code, required this.newPassword});
  @override
  List<Object?> get props => [email, code, newPassword];
}

class AuthMessageCleared extends AuthEvent {
  const AuthMessageCleared();
}
