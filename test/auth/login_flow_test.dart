import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cobra/config/routes/app_routes.dart';
import 'package:cobra/features/auth/presentation/bloc/auth_bloc.dart';
import 'fake_auth_repository.dart';

void main() {
  Future<AuthBloc> abrirApp(WidgetTester tester) async {
    final bloc = AuthBloc(repository: FakeAuthRepository());
    addTearDown(bloc.close);
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
      value: bloc,
      child: MaterialApp.router(routerConfig: createRouter(bloc)),
    ));
    await tester.pumpAndSettle();
    return bloc;
  }

  testWidgets('sin sesión, la app abre en el login', (tester) async {
    await abrirApp(tester);

    expect(find.text('Ingresá a tu cuenta'), findsOneWidget);
    expect(find.text('Probar sin cuenta'), findsOneWidget);
  });

  testWidgets('el login valida los campos antes de enviar', (tester) async {
    final bloc = await abrirApp(tester);

    await tester.tap(find.text('Ingresar'));
    await tester.pump();

    expect(find.text('Ingresá tu correo'), findsOneWidget);
    expect(find.text('Ingresá tu contraseña'), findsOneWidget);
    expect(bloc.state.isLoading, isFalse);
  });

  testWidgets('desde el login se llega a crear cuenta y se valida',
      (tester) async {
    await abrirApp(tester);

    await tester.tap(find.text('Crear una cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Creá tu cuenta'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'ana@correo.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'corta');
    await tester.enterText(find.byType(TextFormField).at(2), 'distinta');
    // El formulario es más alto que la pantalla de prueba: se hace scroll hasta el botón.
    await tester.ensureVisible(find.text('Crear cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(find.text('Usá al menos 8 caracteres'), findsOneWidget);
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
  });

  testWidgets('desde el login se llega a recuperar contraseña',
      (tester) async {
    await abrirApp(tester);

    await tester.tap(find.text('Olvidé mi contraseña'));
    await tester.pumpAndSettle();

    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(find.text('Enviar código'), findsOneWidget);
  });
}
