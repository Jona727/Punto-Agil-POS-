import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/primary_button.dart';
import '../bloc/auth_bloc.dart';
import 'auth_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const AuthMessageCleared());
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context
        .read<AuthBloc>()
        .add(AuthSignUpRequested(_email.text, _password.text));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBack: true,
      title: 'Creá tu cuenta',
      subtitle: 'Es gratis para empezar. Solo necesitás un correo.',
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          // Cuenta creada pero falta confirmar el correo: volver al login.
          if (state.info != null && state.status == AuthStatus.unauthenticated) {
            context.pop();
          }
        },
        builder: (context, state) {
          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthMessage(error: state.error),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: authFieldDecoration('Correo', icon: Icons.mail_outline),
                  validator: AppValidators.email,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _password,
                  obscureText: _hidePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  decoration: authFieldDecoration(
                          'Contraseña (mínimo ${AppValidators.minPasswordLength} caracteres)',
                          icon: Icons.lock_outline)
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_hidePassword
                          ? Icons.visibility_off
                          : Icons.visibility),
                      onPressed: () =>
                          setState(() => _hidePassword = !_hidePassword),
                    ),
                  ),
                  validator: AppValidators.password,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirm,
                  obscureText: _hidePassword,
                  decoration: authFieldDecoration('Repetí la contraseña',
                      icon: Icons.lock_outline),
                  validator: AppValidators.sameAs(() => _password.text),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  onPressed: state.isLoading ? null : _submit,
                  label: 'Crear cuenta',
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
