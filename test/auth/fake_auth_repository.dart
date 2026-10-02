import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:cobra/core/error/failure.dart';
import 'package:cobra/features/auth/domain/entities/app_user.dart';
import 'package:cobra/features/auth/domain/repositories/auth_repository.dart';

const ana = AppUser(id: 'u1', email: 'ana@correo.com');

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.available = true,
    AppUser? user,
    this.guest = false,
  }) : _user = user;

  final bool available;
  AppUser? _user;
  bool guest;

  /// Qué devuelve signUp: un usuario (entra directo) o null (falta confirmar).
  AppUser? signUpResult = ana;
  Failure? failure;
  final _changes = StreamController<AppUser?>.broadcast();

  /// Simula un cambio de sesión (por ejemplo, que venza).
  void emitUser(AppUser? user) => _changes.add(user);

  @override
  bool get isAvailable => available;
  @override
  AppUser? get currentUser => _user;
  @override
  Stream<AppUser?> get authChanges => _changes.stream;
  @override
  bool get isGuest => guest;
  @override
  Future<void> setGuest(bool value) async => guest = value;

  @override
  Future<Either<Failure, AppUser>> signIn(String email, String password) async {
    if (failure != null) return Left(failure!);
    return Right(_user = ana);
  }

  @override
  Future<Either<Failure, AppUser?>> signUp(String email, String password) async {
    if (failure != null) return Left(failure!);
    return Right(signUpResult);
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    _user = null;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> requestPasswordReset(String email) async =>
      failure != null ? Left(failure!) : const Right(null);

  @override
  Future<Either<Failure, AppUser>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async =>
      failure != null ? Left(failure!) : Right(_user = ana);
}
