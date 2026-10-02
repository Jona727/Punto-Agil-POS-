import 'package:flutter_test/flutter_test.dart';
import 'package:cobra/core/utils/app_validators.dart';

void main() {
  group('AppValidators.required', () {
    final validator = AppValidators.required('Obligatorio');

    test('rechaza null, vacío y solo espacios', () {
      expect(validator(null), 'Obligatorio');
      expect(validator(''), 'Obligatorio');
      expect(validator('   '), 'Obligatorio');
    });

    test('acepta texto', () {
      expect(validator('Yerba'), isNull);
    });
  });

  group('AppValidators.price', () {
    test('rechaza vacío, texto y negativos', () {
      expect(AppValidators.price(null), isNotNull);
      expect(AppValidators.price(''), isNotNull);
      expect(AppValidators.price('abc'), isNotNull);
      expect(AppValidators.price('-5'), isNotNull);
    });

    test('acepta números válidos, incluido cero', () {
      expect(AppValidators.price('1500'), isNull);
      expect(AppValidators.price('99.50'), isNull);
      expect(AppValidators.price('0'), isNull);
    });
  });
}
