import 'package:flutter_test/flutter_test.dart';
import 'package:cobra/core/utils/app_validators.dart';
import 'package:cobra/features/auth/data/repositories/supabase_auth_repository.dart';

void main() {
  group('correo', () {
    test('rechaza vacío y formatos inválidos', () {
      expect(AppValidators.email(null), isNotNull);
      expect(AppValidators.email(''), isNotNull);
      expect(AppValidators.email('ana'), isNotNull);
      expect(AppValidators.email('ana@'), isNotNull);
      expect(AppValidators.email('ana@correo'), isNotNull);
      expect(AppValidators.email('a na@correo.com'), isNotNull);
    });

    test('acepta correos válidos, ignorando espacios al borde', () {
      expect(AppValidators.email('ana@correo.com'), isNull);
      expect(AppValidators.email('  ana.perez@mi-negocio.com.ar '), isNull);
    });
  });

  group('contraseña', () {
    test('exige al menos 8 caracteres', () {
      expect(AppValidators.password(null), isNotNull);
      expect(AppValidators.password(''), isNotNull);
      expect(AppValidators.password('1234567'), isNotNull);
      expect(AppValidators.password('12345678'), isNull);
    });

    test('la confirmación debe coincidir', () {
      final validator = AppValidators.sameAs(() => 'secreta123');
      expect(validator('secreta123'), isNull);
      expect(validator('otra'), isNotNull);
    });
  });

  group('mensajes de error de Supabase', () {
    test('traduce los códigos conocidos', () {
      expect(mensajeDeErrorAuth('invalid_credentials'), contains('incorrectos'));
      expect(mensajeDeErrorAuth('user_already_exists'), contains('Ya existe'));
      expect(mensajeDeErrorAuth('email_exists'), contains('Ya existe'));
      expect(mensajeDeErrorAuth('email_not_confirmed'), contains('Confirmá'));
      expect(mensajeDeErrorAuth('weak_password'), contains('8'));
      expect(mensajeDeErrorAuth('otp_expired'), contains('código'));
    });

    test('los códigos desconocidos dan un mensaje genérico en español', () {
      expect(mensajeDeErrorAuth(null), contains('Intentá de nuevo'));
      expect(mensajeDeErrorAuth('algo_raro'), contains('Intentá de nuevo'));
    });
  });
}
