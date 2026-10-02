import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/primary_button.dart';
import '../bloc/auth_bloc.dart';
import 'auth_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
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
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context
        .read<AuthBloc>()
        .add(AuthSignInRequested(_email.text, _password.text));
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Ingresá a tu cuenta',
      subtitle: 'Tus productos y ventas quedan respaldados en la nube.',
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          return Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthMessage(error: state.error, info: state.info),
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
                  autofillHints: const [AutofillHints.password],
                  decoration: authFieldDecoration('Contraseña',
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
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Ingresá tu contraseña'
                      : null,
                  onFieldSubmitted: (_) => _submit(),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const Text('Olvidé mi contraseña'),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  onPressed: state.isLoading ? null : _submit,
                  label: 'Ingresar',
                  isLoading: state.isLoading,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: state.isLoading ? null : () => context.push('/register'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Crear una cuenta'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: state.isLoading
                      ? null
                      : () => context
                          .read<AuthBloc>()
                          .add(const AuthGuestRequested()),
                  child: const Text('Probar sin cuenta'),
                ),
                Text(
                  'Sin cuenta, los datos se guardan solo en este teléfono.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
