import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository repository;
  StreamSubscription<AppUser?>? _sub;

  AuthBloc({required this.repository}) : super(_initialState(repository)) {
    on<AuthUserChanged>(_onUserChanged);
    on<AuthSignInRequested>(_onSignIn);
    on<AuthSignUpRequested>(_onSignUp);
    on<AuthSignOutRequested>(_onSignOut);
    on<AuthGuestRequested>(_onGuest);
    on<AuthPasswordResetRequested>(_onResetRequested);
    on<AuthPasswordResetConfirmed>(_onResetConfirmed);
    on<AuthMessageCleared>((event, emit) =>
        emit(state.copyWith(clearMessages: true, resetCodeSent: false)));

    _sub = repository.authChanges.listen((user) => add(AuthUserChanged(user)));
  }

  /// Sin Supabase configurado la app funciona local, como "invitado".
  static AuthState _initialState(AuthRepository repo) {
    final user = repo.currentUser;
    if (user != null) return AuthState(status: AuthStatus.authenticated, user: user);
    if (!repo.isAvailable || repo.isGuest) {
      return const AuthState(status: AuthStatus.guest);
    }
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  void _onUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    final user = event.user;
    if (user != null) {
      emit(AuthState(status: AuthStatus.authenticated, user: user));
    } else if (state.status == AuthStatus.authenticated) {
      // La sesión terminó (cerró sesión o venció).
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future<void> _onSignIn(
      AuthSignInRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    final result = await repository.signIn(event.email, event.password);
    await result.fold(
      (failure) async =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (user) async {
        await repository.setGuest(false);
        emit(AuthState(status: AuthStatus.authenticated, user: user));
      },
    );
  }

  Future<void> _onSignUp(
      AuthSignUpRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    final result = await repository.signUp(event.email, event.password);
    await result.fold(
      (failure) async =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (user) async {
        if (user == null) {
          emit(state.copyWith(
            isLoading: false,
            info: 'Te enviamos un correo para confirmar tu cuenta. '
                'Confirmalo y después ingresá.',
          ));
        } else {
          await repository.setGuest(false);
          emit(AuthState(status: AuthStatus.authenticated, user: user));
        }
      },
    );
  }

  Future<void> _onSignOut(
      AuthSignOutRequested event, Emitter<AuthState> emit) async {
    if (state.status == AuthStatus.authenticated) {
      emit(state.copyWith(isLoading: true, clearMessages: true));
      final result = await repository.signOut();
      if (result.isLeft()) {
        emit(state.copyWith(
            isLoading: false, error: 'No se pudo cerrar la sesión.'));
        return;
      }
    }
    await repository.setGuest(false);
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  Future<void> _onGuest(
      AuthGuestRequested event, Emitter<AuthState> emit) async {
    await repository.setGuest(true);
    emit(const AuthState(status: AuthStatus.guest));
  }

  Future<void> _onResetRequested(
      AuthPasswordResetRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    final result = await repository.requestPasswordReset(event.email);
    result.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (_) => emit(state.copyWith(
        isLoading: false,
        resetCodeSent: true,
        info: 'Si el correo está registrado, te enviamos un código de 6 dígitos.',
      )),
    );
  }

  Future<void> _onResetConfirmed(
      AuthPasswordResetConfirmed event, Emitter<AuthState> emit) async {
    emit(state.copyWith(isLoading: true, clearMessages: true));
    final result = await repository.confirmPasswordReset(
      email: event.email,
      code: event.code,
      newPassword: event.newPassword,
    );
    await result.fold(
      (failure) async =>
          emit(state.copyWith(isLoading: false, error: failure.message)),
      (user) async {
        await repository.setGuest(false);
        emit(AuthState(status: AuthStatus.authenticated, user: user));
      },
    );
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
