part of 'billing_bloc.dart';

class BillingState extends Equatable {
  final List<CartItem> cartItems;
  final String? error;

  /// Código leído que no está en los productos del comercio. La pantalla abre la
  /// ventana de alta rápida y después lo limpia.
  final String? unknownBarcode;
  final bool isPrinting;
  final bool printSuccess;
  final List<Sale> dailySales;
  final bool isDailySalesLoading;

  /// Id de la venta ya registrada para el carrito actual (evita duplicados
  /// si se reintenta imprimir).
  final String? savedSaleId;

  /// Cómo va a pagar el cliente. Se fija al registrar la venta.
  final PaymentMethod paymentMethod;

  const BillingState({
    this.cartItems = const [],
    this.error,
    this.unknownBarcode,
    this.isPrinting = false,
    this.printSuccess = false,
    this.savedSaleId,
    this.paymentMethod = PaymentMethod.cash,
    this.dailySales = const [],
    this.isDailySalesLoading = false,
  });

  /// La venta de este carrito ya quedó registrada (se puede imprimir o terminar).
  bool get isSaleRegistered => savedSaleId != null;

  double get totalAmount => cartItems.fold(0, (sum, item) => sum + item.total);

  BillingState copyWith({
    List<CartItem>? cartItems,
    String? error,
    bool clearError = false,
    String? unknownBarcode,
    bool clearUnknownBarcode = false,
    bool? isPrinting,
    bool? printSuccess,
    String? savedSaleId,
    PaymentMethod? paymentMethod,
    List<Sale>? dailySales,
    bool? isDailySalesLoading,
  }) {
    return BillingState(
      cartItems: cartItems ?? this.cartItems,
      error: clearError ? null : (error ?? this.error),
      unknownBarcode:
          clearUnknownBarcode ? null : (unknownBarcode ?? this.unknownBarcode),
      isPrinting: isPrinting ?? this.isPrinting,
      printSuccess: printSuccess ?? this.printSuccess,
      savedSaleId: savedSaleId ?? this.savedSaleId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      dailySales: dailySales ?? this.dailySales,
      isDailySalesLoading: isDailySalesLoading ?? this.isDailySalesLoading,
    );
  }

  @override
  List<Object?> get props => [
        cartItems,
        error,
        unknownBarcode,
        isPrinting,
        printSuccess,
        savedSaleId,
        paymentMethod,
        dailySales,
        isDailySalesLoading,
      ];
}
