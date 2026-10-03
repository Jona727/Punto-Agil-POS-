import 'package:equatable/equatable.dart';

class Shop extends Equatable {
  final String name;
  final String addressLine1;
  final String addressLine2;
  final String phoneNumber;
  final String paymentAlias;

  /// Contenido del QR de cobro del comercio (Mercado Pago o banco), leído de una
  /// imagen. Vacío = todavía no cargó uno.
  final String paymentQr;
  final String footerText;

  const Shop({
    this.name = '',
    this.addressLine1 = '',
    this.addressLine2 = '',
    this.phoneNumber = '',
    this.paymentAlias = '',
    this.paymentQr = '',
    this.footerText = '',
  });

  Shop copyWith({
    String? name,
    String? addressLine1,
    String? addressLine2,
    String? phoneNumber,
    String? paymentAlias,
    String? paymentQr,
    String? footerText,
  }) {
    return Shop(
      name: name ?? this.name,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      paymentAlias: paymentAlias ?? this.paymentAlias,
      paymentQr: paymentQr ?? this.paymentQr,
      footerText: footerText ?? this.footerText,
    );
  }

  @override
  List<Object?> get props => [
    name,
    addressLine1,
    addressLine2,
    phoneNumber,
    paymentAlias,
    paymentQr,
    footerText,
  ];
}
