import 'dart:async';

import 'package:cobra/core/widgets/input_label.dart';
import 'package:cobra/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/service_locator.dart' as di;
import '../../../catalog/domain/barcode.dart';
import '../../../catalog/domain/catalog_product.dart';
import '../../../catalog/domain/catalog_repository.dart';
import '../bloc/product_bloc.dart';
import '../../domain/entities/product.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';

class AddProductPage extends StatefulWidget {
  /// Se puede reemplazar en las pruebas; en la app se usa el catálogo real.
  final CatalogRepository? catalog;

  const AddProductPage({super.key, this.catalog});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  double _price = 0.0;

  late final CatalogRepository _catalog =
      widget.catalog ?? di.sl<CatalogRepository>();

  /// Sugerencia del catálogo para el código escrito (null = no hay).
  CatalogProduct? _suggestion;

  /// Nombre que completó el catálogo; sirve para saber si el comercio lo
  /// cambió (en ese caso no se pisa).
  String? _autoFilledName;
  bool _barcodeLooksWrong = false;
  String _lastLookedUp = '';
  int _lookupSeq = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _barcodeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _scanBarcode() async {
    final result = await context.push<String>('/scanner');
    if (result != null && result.isNotEmpty) {
      _barcodeController.text = result;
      _onBarcodeChanged(result, immediate: true);
    }
  }

  /// Al escribir se espera un instante a que termine de tipear; al escanear se
  /// busca enseguida. Así un código a medio escribir no trae sugerencias falsas.
  void _onBarcodeChanged(String value, {bool immediate = false}) {
    _debounce?.cancel();
    if (immediate) {
      _lookup(value);
    } else {
      _debounce = Timer(
        const Duration(milliseconds: 350),
        () => _lookup(value),
      );
    }
  }

  Future<void> _lookup(String value) async {
    final code = normalizeBarcode(value);
    if (code == null) {
      _lastLookedUp = '';
      _lookupSeq++;
      _dropSuggestion();
      return;
    }
    if (code == _lastLookedUp) return;
    _lastLookedUp = code;
    _dropSuggestion(); // el código cambió: la sugerencia anterior ya no vale
    final seq = ++_lookupSeq;

    final found = await _catalog.lookup(code);
    if (!mounted || seq != _lookupSeq) {
      return; // llegó tarde: el código ya cambió
    }

    setState(() {
      _barcodeLooksWrong = !barcodeChecksumOk(code);
      _suggestion = found;
      if (found != null && _nameController.text.trim().isEmpty) {
        _nameController.text = found.name;
        _autoFilledName = found.name;
      }
    });
  }

  void _dropSuggestion() {
    if (!mounted) return;
    setState(() {
      // Si el nombre lo había puesto el catálogo y nadie lo tocó, se limpia.
      if (_autoFilledName != null && _nameController.text == _autoFilledName) {
        _nameController.clear();
      }
      _autoFilledName = null;
      _suggestion = null;
      _barcodeLooksWrong = false;
    });
  }

  void _useSuggestion() {
    final suggestion = _suggestion;
    if (suggestion == null) return;
    setState(() {
      _nameController.text = suggestion.name;
      _autoFilledName = suggestion.name;
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final barcode = _barcodeController.text.trim();

      final productState = context.read<ProductBloc>().state;
      final existingProduct = productState.products
          .where((p) => p.barcode == barcode)
          .firstOrNull;

      if (existingProduct != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ya existe un producto con el código "$barcode"'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final product = Product(
        id: const Uuid().v4(),
        name: _nameController.text.trim(),
        barcode: barcode,
        price: _price,
      );

      context.read<ProductBloc>().add(AddProduct(product));
      context.pop();
    }
  }

  Widget _buildSuggestion() {
    final suggestion = _suggestion;
    if (suggestion == null) return const SizedBox.shrink();
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _nameController,
      builder: (context, value, _) {
        final usingIt = value.text.trim() == suggestion.name;
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: usingIt
              ? Text(
                  '✅ Nombre del catálogo. Editalo si hace falta.',
                  style: TextStyle(fontSize: 12, color: Colors.green[700]),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.auto_fix_high, size: 16),
                    label: Text('Usar el del catálogo: ${suggestion.name}'),
                    onPressed: _useSuggestion,
                  ),
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.chevron_left,
            size: 28,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Agregar producto',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const InputLabel(text: 'Código de barras'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _barcodeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Escaneá o ingresá el código',
                        ),
                        validator: AppValidators.required(
                          'Ingresá un código de barras',
                        ),
                        onChanged: _onBarcodeChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.qr_code_scanner,
                          color: AppTheme.primaryColor,
                        ),
                        onPressed: _scanBarcode,
                        padding: const EdgeInsets.all(14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Escribí el código o tocá el ícono para escanearlo. Si el '
                  'producto está en el catálogo, el nombre se completa solo.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF4C669A)),
                ),
                if (_barcodeLooksWrong)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Revisá el código: no coincide su dígito de control. Si es '
                      'un código propio, podés usarlo igual.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                    ),
                  ),
                const SizedBox(height: 24),
                const InputLabel(text: 'Nombre del producto'),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Ej: Yerba Mate 1kg',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: AppValidators.required('Ingresá un nombre'),
                ),
                _buildSuggestion(),
                const SizedBox(height: 24),
                const InputLabel(text: 'Precio'),
                TextFormField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    prefixText: '\$ ',
                    prefixStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  validator: AppValidators.price,
                  onSaved: (value) => _price = double.parse(value!),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: PrimaryButton(
        onPressed: _submit,
        icon: Icons.add_circle,
        label: 'Agregar producto',
      ),
    );
  }
}
