import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../domain/entities/cart_item.dart';
import 'package:billing_app/features/product/domain/entities/product.dart';
import 'package:billing_app/features/product/domain/usecases/product_usecases.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/bluetooth_printer_helper.dart';
import '../../../../core/data/hive_database.dart';
import '../../domain/usecases/sale_usecases.dart';
import '../../domain/entities/sale.dart';
import 'package:uuid/uuid.dart';

part 'billing_event.dart';
part 'billing_state.dart';

class BillingBloc extends Bloc<BillingEvent, BillingState> {
  final GetProductByBarcodeUseCase getProductByBarcodeUseCase;
  final SaveSaleUseCase saveSaleUseCase;
  final GetDailySalesUseCase getDailySalesUseCase;

  BillingBloc({
    required this.getProductByBarcodeUseCase,
    required this.saveSaleUseCase,
    required this.getDailySalesUseCase,
  }) : super(const BillingState()) {
    on<ScanBarcodeEvent>(_onScanBarcode);
    on<AddProductToCartEvent>(_onAddProductToCart);
    on<RemoveProductFromCartEvent>(_onRemoveProductFromCart);
    on<UpdateQuantityEvent>(_onUpdateQuantity);
    on<UpdateItemPriceEvent>(_onUpdateItemPrice);
    on<ClearCartEvent>(_onClearCart);
    on<PrintReceiptEvent>(_onPrintReceipt);
    on<PrintZReportEvent>(_onPrintZReport);
  }

  Future<void> _onScanBarcode(
      ScanBarcodeEvent event, Emitter<BillingState> emit) async {
    final result = await getProductByBarcodeUseCase(event.barcode);
    result.fold(
      (failure) =>
          emit(state.copyWith(error: 'Product not found: ${event.barcode}')),
      (product) {
        add(AddProductToCartEvent(product));
      },
    );
  }

  void _onAddProductToCart(
      AddProductToCartEvent event, Emitter<BillingState> emit) {
    // Clear error when adding
    final cleanState = state.copyWith(error: null);

    final existingIndex = cleanState.cartItems
        .indexWhere((item) => item.product.id == event.product.id);
    if (existingIndex >= 0) {
      final existingItem = cleanState.cartItems[existingIndex];
      final backendItems = List<CartItem>.from(cleanState.cartItems);
      backendItems[existingIndex] =
          existingItem.copyWith(quantity: existingItem.quantity + 1);
      emit(cleanState.copyWith(cartItems: backendItems, error: null));
    } else {
      final newItem = CartItem(product: event.product);
      emit(cleanState.copyWith(
          cartItems: [...cleanState.cartItems, newItem], error: null));
    }
  }

  void _onRemoveProductFromCart(
      RemoveProductFromCartEvent event, Emitter<BillingState> emit) {
    final updatedList = state.cartItems
        .where((item) => item.product.id != event.productId)
        .toList();
    emit(state.copyWith(cartItems: updatedList));
  }

  void _onUpdateQuantity(
      UpdateQuantityEvent event, Emitter<BillingState> emit) {
    if (event.quantity <= 0) {
      add(RemoveProductFromCartEvent(event.productId));
      return;
    }

    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      items[index] = items[index].copyWith(quantity: event.quantity);
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onUpdateItemPrice(
      UpdateItemPriceEvent event, Emitter<BillingState> emit) {
    if (event.newPrice < 0) return; // Prevent negative prices

    final index = state.cartItems
        .indexWhere((item) => item.product.id == event.productId);
    
    if (index >= 0) {
      final items = List<CartItem>.from(state.cartItems);
      final item = items[index];
      
      // Override the internal product representation for this local sale
      final modifiedProduct = item.product.copyWith(price: event.newPrice);
      
      // Swap the item back into the cart
      items[index] = item.copyWith(product: modifiedProduct);
      
      emit(state.copyWith(cartItems: items));
    }
  }

  void _onClearCart(ClearCartEvent event, Emitter<BillingState> emit) {
    emit(const BillingState());
  }

  Future<void> _onPrintReceipt(
      PrintReceiptEvent event, Emitter<BillingState> emit) async {
    final wifiHelper = PrinterHelper();
    final btHelper = BluetoothPrinterHelper();
    bool usingBluetooth = false;

    // ── Step 1: try to use/establish a connection ─────────────────────────
    if (!wifiHelper.isConnected && !btHelper.isConnected) {
      // Try WiFi first
      final savedIp = HiveDatabase.settingsBox.get('printer_ip') as String?;
      if (savedIp != null && savedIp.isNotEmpty) {
        final connected = await wifiHelper.connect(savedIp);
        if (!connected) {
          emit(state.copyWith(
              error: 'Failed to auto-connect to Wi-Fi printer!',
              clearError: false));
          emit(state.copyWith(clearError: true));
          return;
        }
      } else {
        // Try Bluetooth fallback
        final savedBtAddr =
            HiveDatabase.settingsBox.get('printer_bt_address') as String?;
        if (savedBtAddr != null && savedBtAddr.isNotEmpty) {
          final device = BluetoothDevice(address: savedBtAddr);
          final connected = await btHelper.connect(device);
          if (!connected) {
            emit(state.copyWith(
                error: 'Failed to auto-connect to Bluetooth printer!',
                clearError: false));
            emit(state.copyWith(clearError: true));
            return;
          }
          usingBluetooth = true;
        } else {
          emit(state.copyWith(
              error: 'No printer configured. Go to Settings → Hardware to add one.',
              clearError: false));
          emit(state.copyWith(clearError: true));
          return;
        }
      }
    } else if (btHelper.isConnected && !wifiHelper.isConnected) {
      usingBluetooth = true;
    }

    // ── Step 2: print ─────────────────────────────────────────────────────
    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    try {
      final items = state.cartItems
          .map((item) => {
                'name': item.product.name,
                'qty': item.quantity,
                'price': item.product.price,
                'total': item.total,
              })
          .toList();

      if (usingBluetooth) {
        await btHelper.printReceipt(
            shopName: event.shopName,
            address1: event.address1,
            address2: event.address2,
            phone: event.phone,
            items: items,
            total: state.totalAmount,
            footer: event.footer);
      } else {
        await wifiHelper.printReceipt(
            shopName: event.shopName,
            address1: event.address1,
            address2: event.address2,
            phone: event.phone,
            items: items,
            total: state.totalAmount,
            footer: event.footer);
      }

      final sale = Sale(
        id: const Uuid().v4(),
        date: DateTime.now(),
        total: state.totalAmount,
      );
      await saveSaleUseCase(sale);

      emit(state.copyWith(isPrinting: false, printSuccess: true));
    } catch (e) {
      emit(state.copyWith(
          isPrinting: false, error: 'Print failed: $e', clearError: false));
      emit(state.copyWith(clearError: true));
    }
  }

  Future<void> _onPrintZReport(
      PrintZReportEvent event, Emitter<BillingState> emit) async {
    emit(state.copyWith(
        isPrinting: true, printSuccess: false, clearError: true));

    final result = await getDailySalesUseCase(DateTime.now());

    await result.fold(
      (failure) async {
        emit(state.copyWith(
            isPrinting: false,
            error: 'Failed to load sales: ${failure.message}',
            clearError: false));
        emit(state.copyWith(clearError: true));
      },
      (sales) async {
        if (sales.isEmpty) {
          emit(state.copyWith(
              isPrinting: false,
              error: 'No sales recorded today to close the batch.',
              clearError: false));
          emit(state.copyWith(clearError: true));
          return;
        }

        double grandTotal = 0;
        for (var sale in sales) {
          grandTotal += sale.total;
        }

        final wifiHelper = PrinterHelper();
        final btHelper = BluetoothPrinterHelper();
        bool usingBluetooth = false;

        if (!wifiHelper.isConnected && !btHelper.isConnected) {
          final savedIp =
              HiveDatabase.settingsBox.get('printer_ip') as String?;
          if (savedIp != null && savedIp.isNotEmpty) {
            final connected = await wifiHelper.connect(savedIp);
            if (!connected) {
              emit(state.copyWith(
                  error: 'Failed to auto-connect to Wi-Fi printer!',
                  clearError: false));
              emit(state.copyWith(clearError: true));
              return;
            }
          } else {
            final savedBtAddr =
                HiveDatabase.settingsBox.get('printer_bt_address') as String?;
            if (savedBtAddr != null && savedBtAddr.isNotEmpty) {
              final device = BluetoothDevice(address: savedBtAddr);
              final connected = await btHelper.connect(device);
              if (!connected) {
                emit(state.copyWith(
                    error: 'Failed to auto-connect to Bluetooth printer!',
                    clearError: false));
                emit(state.copyWith(clearError: true));
                return;
              }
              usingBluetooth = true;
            } else {
              emit(state.copyWith(
                  error: 'No printer configured. Go to Settings → Hardware to add one.',
                  clearError: false));
              emit(state.copyWith(clearError: true));
              return;
            }
          }
        } else if (btHelper.isConnected && !wifiHelper.isConnected) {
          usingBluetooth = true;
        }

        try {
          // Format the Z Report mimicking a receipt but replacing item list with summary
          final items = [
            {
              'name': 'TOTAL TRANSACTIONS',
              'qty': sales.length,
              'price': 0.0,
              'total': 0.0,
            },
            {
              'name': 'GROSS SALES',
              'qty': 1,
              'price': grandTotal,
              'total': grandTotal,
            }
          ];

          final receiptArgs = (
            shopName: '*** Z REPORT ***\n${event.shopName}',
            address1: 'END OF DAY BATCH',
            address2: 'Date: ${DateTime.now().toString().substring(0, 16)}',
            phone: '',
            items: items,
            total: grandTotal,
            footer: 'Z-REPORT CLOSED SUCCESSFULLY',
          );
          if (usingBluetooth) {
            await btHelper.printReceipt(
              shopName: receiptArgs.shopName,
              address1: receiptArgs.address1,
              address2: receiptArgs.address2,
              phone: receiptArgs.phone,
              items: receiptArgs.items,
              total: receiptArgs.total,
              footer: receiptArgs.footer,
            );
          } else {
            await wifiHelper.printReceipt(
              shopName: receiptArgs.shopName,
              address1: receiptArgs.address1,
              address2: receiptArgs.address2,
              phone: receiptArgs.phone,
              items: receiptArgs.items,
              total: receiptArgs.total,
              footer: receiptArgs.footer,
            );
          }

          emit(state.copyWith(isPrinting: false, printSuccess: true));
        } catch (e) {
          emit(state.copyWith(
              isPrinting: false, error: 'Print failed: $e', clearError: false));
          emit(state.copyWith(clearError: true));
        }
      },
    );
  }
}
