class AppValidators {
  static String? Function(String?) required(String message) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return message;
      }
      return null;
    };
  }

  static String? price(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresá un precio';
    }
    if (double.tryParse(value) == null) {
      return 'Ingresá un número válido';
    }
    if (double.parse(value) < 0) {
      return 'El precio no puede ser negativo';
    }
    return null;
  }

  static final _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ingresá tu correo';
    }
    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Ingresá un correo válido';
    }
    return null;
  }

  static const int minPasswordLength = 8;

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ingresá una contraseña';
    }
    if (value.length < minPasswordLength) {
      return 'Usá al menos $minPasswordLength caracteres';
    }
    return null;
  }

  static String? Function(String?) sameAs(String Function() other) {
    return (String? value) =>
        value == other() ? null : 'Las contraseñas no coinciden';
  }

  /// Lee un precio escrito a mano; acepta coma o punto como separador decimal.
  static double? parsePrice(String? value) {
    if (value == null) return null;
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  /// Precio obligatorio y mayor a cero (para vender un producto).
  static String? positivePrice(String? value) {
    if (value == null || value.trim().isEmpty) return 'Ingresá el precio';
    final price = parsePrice(value);
    if (price == null) return 'Ingresá un número válido';
    if (price <= 0) return 'El precio debe ser mayor a 0';
    return null;
  }
}
