import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/primary_button.dart';
import '../bloc/auth_bloc.dart';
import 'auth_widgets.dart';

/// Recuperar contraseña en dos pasos: 1) pedir el código por correo,
/// 2) ingresar el código y la contraseña nueva.
/// Al terminar, el AuthBloc deja la sesión iniciada y el router entra a la app.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailKey = GlobalKey<FormState>();
  final _resetKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const AuthMessageCleared());
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  void _requestCode() {
    if (!_emailKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthPasswordResetRequested(_email.text));
  }

  void _confirm() {
    if (!_resetKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthPasswordResetConfirmed(
          email: _email.text,
          code: _code.text,
          newPassword: _password.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: 'Recuperar contraseña',
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (!state.resetCodeSent) {
            return Form(
              key: _emailKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthMessage(error: state.error),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        authFieldDecoration('Correo', icon: Icons.mail_outline),
                    validator: AppValidators.email,
                    onFieldSubmitted: (_) => _requestCode(),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    onPressed: state.isLoading ? null : _requestCode,
                    label: 'Enviar código',
                    isLoading: state.isLoading,
                  ),
                ],
              ),
            );
          }

          return Form(
            key: _resetKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthMessage(error: state.error, info: state.info),
                TextFormField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  decoration: authFieldDecoration('Código del correo',
                      icon: Icons.pin_outlined),
                  validator: AppValidators.required('Ingresá el código'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: authFieldDecoration('Contraseña nueva',
                      icon: Icons.lock_outline),
                  validator: AppValidators.password,
                  onFieldSubmitted: (_) => _confirm(),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  onPressed: state.isLoading ? null : _confirm,
                  label: 'Cambiar contraseña',
                  isLoading: state.isLoading,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
