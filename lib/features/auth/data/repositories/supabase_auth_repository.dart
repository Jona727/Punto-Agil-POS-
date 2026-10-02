import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/data/hive_database.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Traduce el código de error de Supabase a un mensaje para el comerciante.
String mensajeDeErrorAuth(String? code) {
  switch (code) {
    case 'invalid_credentials':
      return 'Correo o contraseña incorrectos.';
    case 'user_already_exists':
    case 'email_exists':
      return 'Ya existe una cuenta con ese correo.';
    case 'email_not_confirmed':
      return 'Confirmá tu correo antes de ingresar. Revisá tu bandeja de entrada.';
    case 'weak_password':
      return 'La contraseña es muy débil. Usá al menos 8 caracteres.';
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
      return 'Demasiados intentos. Esperá unos minutos y probá de nuevo.';
    case 'otp_expired':
      return 'El código venció o es incorrecto. Pedí uno nuevo.';
    default:
      return 'No se pudo completar la operación. Intentá de nuevo.';
  }
}

const _sinConexion = 'Sin conexión a internet. Verificá tu red e intentá de nuevo.';
const _guestKey = 'guest_mode';

class SupabaseAuthRepository implements AuthRepository {
  @override
  bool get isAvailable => AppConfig.isSupabaseConfigured;

  GoTrueClient get _auth => Supabase.instance.client.auth;

  AppUser? _map(User? user) =>
      user == null ? null : AppUser(id: user.id, email: user.email ?? '');

  @override
  AppUser? get currentUser => isAvailable ? _map(_auth.currentUser) : null;

  @override
  Stream<AppUser?> get authChanges => isAvailable
      ? _auth.onAuthStateChange.map((state) => _map(state.session?.user))
      : const Stream.empty();

  @override
  bool get isGuest =>
      HiveDatabase.settingsBox.get(_guestKey, defaultValue: false) as bool;

  @override
  Future<void> setGuest(bool value) =>
      HiveDatabase.settingsBox.put(_guestKey, value);

  Future<Either<Failure, T>> _run<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on AuthException catch (e) {
      return Left(AuthFailure(mensajeDeErrorAuth(e.code)));
    } on TimeoutException {
      return const Left(AuthFailure(_sinConexion));
    } catch (_) {
      // Sin red, Supabase lanza errores de socket / cliente HTTP.
      return const Left(AuthFailure(_sinConexion));
    }
  }

  @override
  Future<Either<Failure, AppUser>> signIn(String email, String password) {
    return _run(() async {
      final res = await _auth.signInWithPassword(
          email: email.trim(), password: password);
      return _map(res.user)!;
    });
  }

  @override
  Future<Either<Failure, AppUser?>> signUp(String email, String password) {
    return _run(() async {
      final res =
          await _auth.signUp(email: email.trim(), password: password);
      // Con confirmación de correo activa no hay sesión hasta confirmar.
      return res.session == null ? null : _map(res.user);
    });
  }

  @override
  Future<Either<Failure, void>> signOut() => _run(() => _auth.signOut());

  @override
  Future<Either<Failure, void>> requestPasswordReset(String email) =>
      _run(() => _auth.resetPasswordForEmail(email.trim()));

  @override
  Future<Either<Failure, AppUser>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) {
    return _run(() async {
      final res = await _auth.verifyOTP(
        email: email.trim(),
        token: code.trim(),
        type: OtpType.recovery,
      );
      await _auth.updateUser(UserAttributes(password: newPassword));
      return _map(res.user ?? _auth.currentUser)!;
    });
  }
}
