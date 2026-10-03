import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../catalog/domain/barcode.dart';
import '../../../catalog/domain/catalog_product.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../../../product/domain/entities/product.dart';

/// Ventana de la caja para un código que el comercio todavía no tiene cargado.
/// Busca el nombre en el catálogo y pide solo el precio. Al confirmar devuelve
/// el [Product] nuevo (con `Navigator.pop`); si se cancela, devuelve null.
class QuickAddProductSheet extends StatefulWidget {
  final String barcode;
  final CatalogRepository catalog;

  const QuickAddProductSheet({
    super.key,
    required this.barcode,
    required this.catalog,
  });

  @override
  State<QuickAddProductSheet> createState() => _QuickAddProductSheetState();
}

class _QuickAddProductSheetState extends State<QuickAddProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _nameFocus = FocusNode();
  final _priceFocus = FocusNode();

  bool _searching = true;
  CatalogProduct? _found;

  @override
  void initState() {
    super.initState();
    _search();
  }

  Future<void> _search() async {
    final found = await widget.catalog.lookup(widget.barcode);
    if (!mounted) return;
    setState(() {
      _searching = false;
      _found = found;
      // Si ya empezó a escribir un nombre, no se lo pisa.
      if (found != null && _nameController.text.trim().isEmpty) {
        _nameController.text = found.name;
      }
    });
    // Con nombre listo se pasa directo al precio; si no, al nombre.
    (found != null ? _priceFocus : _nameFocus).requestFocus();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _nameFocus.dispose();
    _priceFocus.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      Product(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        // Se guarda en forma canónica para encontrarlo luego con cualquier lector.
        barcode: normalizeBarcode(widget.barcode) ?? widget.barcode.trim(),
        price: AppValidators.parsePrice(_priceController.text)!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Sube con el teclado.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Producto nuevo',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Código ${widget.barcode}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                _statusLine(),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej: Alfajor de chocolate',
                  ),
                  validator: AppValidators.required('Ingresá un nombre'),
                  onFieldSubmitted: (_) => _priceFocus.requestFocus(),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _priceController,
                  focusNode: _priceFocus,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Precio de venta',
                    prefixText: '\$ ',
                  ),
                  validator: AppValidators.positivePrice,
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  onPressed: _submit,
                  icon: Icons.add_shopping_cart,
                  label: 'Agregar a la venta',
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusLine() {
    if (_searching) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Buscando en el catálogo…',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      );
    }
    if (_found != null) {
      return Text(
        '✅ Encontrado en el catálogo. Solo falta el precio.',
        style: TextStyle(fontSize: 13, color: Colors.green[700]),
      );
    }
    return Text(
      'No está en el catálogo: escribí el nombre y el precio.',
      style: TextStyle(fontSize: 13, color: AppTheme.primaryColor),
    );
  }
}
