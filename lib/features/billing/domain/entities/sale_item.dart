import 'package:equatable/equatable.dart';

/// Una línea de una venta: copia del producto al momento de vender
/// (así el historial no cambia si luego se edita el precio del producto).
class SaleItem extends Equatable {
  final String productId;
  final String name;
  final String barcode;
  final double unitPrice;
  final int quantity;

  const SaleItem({
    required this.productId,
    required this.name,
    required this.barcode,
    required this.unitPrice,
    required this.quantity,
  });

  double get subtotal => unitPrice * quantity;

  @override
  List<Object?> get props => [productId, name, barcode, unitPrice, quantity];
}
