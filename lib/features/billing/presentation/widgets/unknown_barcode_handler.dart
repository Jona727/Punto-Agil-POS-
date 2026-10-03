import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/service_locator.dart' as di;
import '../../../catalog/domain/catalog_repository.dart';
import '../../../product/domain/entities/product.dart';
import '../../../product/presentation/bloc/product_bloc.dart';
import '../bloc/billing_bloc.dart';
import 'quick_add_product_sheet.dart';

/// Cuando la caja lee un código que el comercio no tiene cargado, abre la
/// ventana de alta rápida (nombre del catálogo + precio). Al confirmar, el
/// producto se guarda en los productos del comercio y se agrega a la venta.
class UnknownBarcodeHandler extends StatelessWidget {
  final Widget child;

  /// Se puede reemplazar en las pruebas; en la app se usa el catálogo real.
  final CatalogRepository? catalog;

  const UnknownBarcodeHandler({super.key, required this.child, this.catalog});

  @override
  Widget build(BuildContext context) {
    return BlocListener<BillingBloc, BillingState>(
      listenWhen: (previous, current) =>
          previous.unknownBarcode != current.unknownBarcode &&
          current.unknownBarcode != null,
      listener: (context, state) => _open(context, state.unknownBarcode!),
      child: child,
    );
  }

  Future<void> _open(BuildContext context, String barcode) async {
    // Se toman antes del await: después la pantalla puede haber cambiado.
    final billing = context.read<BillingBloc>();
    final products = context.read<ProductBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final repository = catalog ?? di.sl<CatalogRepository>();

    final product = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          QuickAddProductSheet(barcode: barcode, catalog: repository),
    );

    // Se libera el código para poder volver a leerlo (también si se canceló).
    billing.add(const ClearUnknownBarcodeEvent());
    if (product == null) return;

    products.add(AddProduct(product));
    billing.add(AddProductToCartEvent(product));
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${product.name} agregado a la venta y guardado en tus productos',
        ),
      ),
    );
  }
}
