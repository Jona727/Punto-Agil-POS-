import 'package:flutter_test/flutter_test.dart';
import 'package:cobra/core/error/failure.dart';
import 'package:cobra/features/auth/presentation/bloc/auth_bloc.dart';
import 'fake_auth_repository.dart';

void main() {
  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

  group('estado inicial', () {
    test('sin Supabase configurado la app funciona como invitado', () {
      final bloc = AuthBloc(repository: FakeAuthRepository(available: false));
      expect(bloc.state.status, AuthStatus.guest);
    });

    test('con Supabase y sin sesión pide ingresar', () {
      final bloc = AuthBloc(repository: FakeAuthRepository());
      expect(bloc.state.status, AuthStatus.unauthenticated);
    });

    test('con sesión guardada entra autenticado', () {
      final bloc = AuthBloc(repository: FakeAuthRepository(user: ana));
      expect(bloc.state.status, AuthStatus.authenticated);
      expect(bloc.state.user, ana);
    });

    test('recuerda que eligió probar sin cuenta', () {
      final bloc = AuthBloc(repository: FakeAuthRepository(guest: true));
      expect(bloc.state.status, AuthStatus.guest);
    });
  });

  group('ingresar', () {
    test('credenciales correctas autentican y salen del modo invitado',
        () async {
      final repo = FakeAuthRepository(guest: true);
      final bloc = AuthBloc(repository: repo);
      bloc.add(const AuthSignInRequested('ana@correo.com', '12345678'));
      await settle();

      expect(bloc.state.status, AuthStatus.authenticated);
      expect(repo.guest, isFalse);
    });

    test('un error se muestra y no autentica', () async {
      final repo = FakeAuthRepository()
        ..failure = const AuthFailure('Correo o contraseña incorrectos.');
      final bloc = AuthBloc(repository: repo);
      bloc.add(const AuthSignInRequested('ana@correo.com', 'mala'));
      await settle();

      expect(bloc.state.status, AuthStatus.unauthenticated);
      expect(bloc.state.error, 'Correo o contraseña incorrectos.');
      expect(bloc.state.isLoading, isFalse);
    });
  });

  group('crear cuenta', () {
    test('si no hace falta confirmar el correo entra directo', () async {
      final bloc = AuthBloc(repository: FakeAuthRepository());
      bloc.add(const AuthSignUpRequested('ana@correo.com', '12345678'));
      await settle();

      expect(bloc.state.status, AuthStatus.authenticated);
    });

    test('si hay que confirmar el correo avisa y no entra', () async {
      final repo = FakeAuthRepository()..signUpResult = null;
      final bloc = AuthBloc(repository: repo);
      bloc.add(const AuthSignUpRequested('ana@correo.com', '12345678'));
      await settle();

      expect(bloc.state.status, AuthStatus.unauthenticated);
      expect(bloc.state.info, contains('confirmar'));
    });
  });

  group('sesión', () {
    test('cerrar sesión vuelve al login', () async {
      final repo = FakeAuthRepository(user: ana);
      final bloc = AuthBloc(repository: repo);
      bloc.add(const AuthSignOutRequested());
      await settle();

      expect(bloc.state.status, AuthStatus.unauthenticated);
      expect(repo.currentUser, isNull);
    });

    test('probar sin cuenta lo recuerda', () async {
      final repo = FakeAuthRepository();
      final bloc = AuthBloc(repository: repo);
      bloc.add(const AuthGuestRequested());
      await settle();

      expect(bloc.state.status, AuthStatus.guest);
      expect(repo.guest, isTrue);
    });

    test('desde invitado, "salir" permite ir a ingresar o registrarse',
        () async {
      final repo = FakeAuthRepository(guest: true);
      final bloc = AuthBloc(repository: repo);
      bloc.add(const AuthSignOutRequested());
      await settle();

      expect(bloc.state.status, AuthStatus.unauthenticated);
      expect(repo.guest, isFalse);
    });

    test('si la sesión vence, vuelve al login', () async {
      final repo = FakeAuthRepository(user: ana);
      final bloc = AuthBloc(repository: repo);
      repo.emitUser(null);
      await settle();

      expect(bloc.state.status, AuthStatus.unauthenticated);
    });
  });

  group('recuperar contraseña', () {
    test('pedir el código pasa al segundo paso', () async {
      final bloc = AuthBloc(repository: FakeAuthRepository());
      bloc.add(const AuthPasswordResetRequested('ana@correo.com'));
      await settle();

      expect(bloc.state.resetCodeSent, isTrue);
    });

    test('con el código correcto inicia sesión', () async {
      final bloc = AuthBloc(repository: FakeAuthRepository());
      bloc.add(const AuthPasswordResetConfirmed(
          email: 'ana@correo.com', code: '123456', newPassword: 'nueva1234'));
      await settle();

      expect(bloc.state.status, AuthStatus.authenticated);
    });

    test('al volver a la pantalla se reinicia el paso', () async {
      final bloc = AuthBloc(repository: FakeAuthRepository());
      bloc.add(const AuthPasswordResetRequested('ana@correo.com'));
      await settle();
      bloc.add(const AuthMessageCleared());
      await settle();

      expect(bloc.state.resetCodeSent, isFalse);
      expect(bloc.state.info, isNull);
    });
  });
}
