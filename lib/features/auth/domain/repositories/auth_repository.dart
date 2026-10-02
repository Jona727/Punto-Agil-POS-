import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failure.dart';
import '../entities/app_user.dart';

abstract class AuthRepository {
  /// false cuando la app se compiló sin datos de Supabase (modo solo local).
  bool get isAvailable;

  AppUser? get currentUser;
  Stream<AppUser?> get authChanges;

  /// El usuario eligió usar la app sin cuenta.
  bool get isGuest;
  Future<void> setGuest(bool value);

  Future<Either<Failure, AppUser>> signIn(String email, String password);

  /// Devuelve null cuando Supabase exige confirmar el correo antes de entrar.
  Future<Either<Failure, AppUser?>> signUp(String email, String password);

  Future<Either<Failure, void>> signOut();

  /// Envía un correo con un código de 6 dígitos.
  Future<Either<Failure, void>> requestPasswordReset(String email);

  /// Valida el código y cambia la contraseña; deja la sesión iniciada.
  Future<Either<Failure, AppUser>> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });
}
