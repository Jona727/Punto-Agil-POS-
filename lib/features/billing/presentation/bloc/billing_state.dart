part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final String? error;
  final bool isPrinting;
  final bool printSuccess;

  /// Id de la venta ya registrada para el carrito actual (evita duplicados
  /// si se reintenta imprimir).
  final String? savedSaleId;

  const BillingState({
    this.cartItems = const [],
    this.error,
    this.isPrinting = false,
    this.printSuccess = false,
    this.savedSaleId,
  });

  double get totalAmount => cartItems.fold(0, (sum, item) => sum + item.total);

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    bool clearError = false,
    bool? isPrinting,
    bool? printSuccess,
    String? savedSaleId,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      error: clearError ? null : (error ?? this.error),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      savedSaleId: savedSaleId ?? this.savedSaleId,
    );
  }

  @override
  List<Object?> get props => [cartItems, error, isPrinting, printSuccess, savedSaleId];
}
