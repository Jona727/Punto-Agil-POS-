part of 'billing_bloc.dart';

abstract class BillingEvent extends Equatable {
  const BillingEvent();

  @override
  List<Object?> get props => [];
}

class ScanBarcodeEvent extends BillingEvent {
  final String barcode;
  const ScanBarcodeEvent(this.barcode);

  @override
  List<Object?> get props => [barcode];
}

/// La pantalla ya atendió el código desconocido (guardó el producto o canceló).
class ClearUnknownBarcodeEvent extends BillingEvent {
  const ClearUnknownBarcodeEvent();
}

class AddProductToCartEvent extends BillingEvent {
  final Product product;
  const AddProductToCartEvent(this.product);

  @override
  List<Object?> get props => [product];
}

class RemoveProductFromCartEvent extends BillingEvent {
  final String productId;
  const RemoveProductFromCartEvent(this.productId);

  @override
  List<Object?> get props => [productId];
}

class UpdateQuantityEvent extends BillingEvent {
  final String productId;
  final int quantity;
  const UpdateQuantityEvent(this.productId, this.quantity);

  @override
  List<Object?> get props => [productId, quantity];
}

class UpdateItemPriceEvent extends BillingEvent {
  final String productId;
  final double newPrice;
  const UpdateItemPriceEvent(this.productId, this.newPrice);

  @override
  List<Object?> get props => [productId, newPrice];
}

class ClearCartEvent extends BillingEvent {}

/// El cajero elige cómo paga el cliente (solo antes de registrar la venta).
class SelectPaymentMethodEvent extends BillingEvent {
  final PaymentMethod method;
  const SelectPaymentMethodEvent(this.method);

  @override
  List<Object?> get props => [method];
}

/// Registra la venta con el medio de pago elegido, sin imprimir.
class ConfirmSaleEvent extends BillingEvent {
  const ConfirmSaleEvent();
}

class PrintReceiptEvent extends BillingEvent {
  final String shopName;
  final String address1;
  final String address2;
  final String phone;
  final String footer;

  const PrintReceiptEvent({
    required this.shopName,
    required this.address1,
    required this.address2,
    required this.phone,
    required this.footer,
  });

  @override
  List<Object?> get props => [shopName, address1, address2, phone, footer];
}

class PrintZReportEvent extends BillingEvent {
  final String shopName;
  const PrintZReportEvent({required this.shopName});

  @override
  List<Object?> get props => [shopName];
}

class LoadDailySalesEvent extends BillingEvent {
  final DateTime date;
  const LoadDailySalesEvent(this.date);

  @override
  List<Object?> get props => [date];
}

class VoidSaleEvent extends BillingEvent {
  final String saleId;
  const VoidSaleEvent(this.saleId);

  @override
  List<Object?> get props => [saleId];
}
