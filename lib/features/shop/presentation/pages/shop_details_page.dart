import 'package:cobra/core/widgets/input_label.dart';
import 'package:cobra/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import '../../data/qr_image_reader.dart';
import '../../domain/payment_qr.dart';
import '../../domain/entities/shop.dart';
import '../bloc/shop_bloc.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_validators.dart';

class ShopDetailsPage extends StatefulWidget {
  /// Se puede reemplazar en las pruebas; en la app se usa la galería.
  final QrImageReader? qrReader;

  const ShopDetailsPage({super.key, this.qrReader});

  @override
  State<ShopDetailsPage> createState() => _ShopDetailsPageState();
}

class _ShopDetailsPageState extends State<ShopDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;
  late TextEditingController _phoneController;
  late TextEditingController _aliasController;
  late TextEditingController _footerController;
  late final QrImageReader _qrReader =
      widget.qrReader ?? GalleryQrImageReader();

  /// Contenido del QR de cobro cargado (vacío = ninguno).
  String _paymentQr = '';
  bool _readingQr = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _address1Controller = TextEditingController();
    _address2Controller = TextEditingController();
    _phoneController = TextEditingController();
    _aliasController = TextEditingController();
    _footerController = TextEditingController();

    // Load shop data
    context.read<ShopBloc>().add(LoadShopEvent());
  }

  void _updateControllers(Shop shop) {
    if (_nameController.text.isEmpty && shop.name.isNotEmpty) {
      _nameController.text = shop.name;
      _address1Controller.text = shop.addressLine1;
      _address2Controller.text = shop.addressLine2;
      _phoneController.text = shop.phoneNumber;
      _aliasController.text = shop.paymentAlias;
      _footerController.text = shop.footerText;
      setState(() => _paymentQr = shop.paymentQr);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _phoneController.dispose();
    _aliasController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  void _saveShop() {
    if (_formKey.currentState!.validate()) {
      final shop = Shop(
        name: _nameController.text,
        addressLine1: _address1Controller.text,
        addressLine2: _address2Controller.text,
        phoneNumber: _phoneController.text,
        paymentAlias: _aliasController.text,
        paymentQr: _paymentQr,
        footerText: _footerController.text,
      );

      context.read<ShopBloc>().add(UpdateShopEvent(shop));
    }
  }

  Future<void> _loadQr() async {
    setState(() => _readingQr = true);
    final result = await _qrReader.pickAndRead();
    if (!mounted) return;
    setState(() => _readingQr = false);

    final messenger = ScaffoldMessenger.of(context);
    if (result.isCancelled) return;
    if (result.error != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.error!), backgroundColor: Colors.red),
      );
      return;
    }
    final payload = result.payload!;
    setState(() => _paymentQr = payload);
    final standard = looksLikePaymentQr(payload);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: standard ? Colors.green : Colors.orange[800],
        content: Text(
          standard
              ? 'QR leído. Tocá "Guardar datos" para usarlo al cobrar.'
              : 'Se leyó el QR, pero no parece un QR de cobro estándar. '
                    'Guardalo y probalo con otro celular antes de usarlo.',
        ),
      ),
    );
  }

  Widget _buildQrSection() {
    final hasQr = _paymentQr.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasQr)
            Row(
              children: [
                SizedBox(
                  width: 96,
                  height: 96,
                  child: PrettyQrView.data(
                    data: _paymentQr,
                    decoration: const PrettyQrDecoration(
                      shape: PrettyQrSquaresSymbol(),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'QR cargado ✅',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Se muestra al cobrar con Mercado Pago.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Wrap(
                        spacing: 4,
                        children: [
                          TextButton(
                            onPressed: _readingQr ? null : _loadQr,
                            child: const Text('Cambiar'),
                          ),
                          TextButton(
                            onPressed: _readingQr
                                ? null
                                : () => setState(() => _paymentQr = ''),
                            child: const Text(
                              'Quitar',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            Text(
              'Buscá el QR de cobro en la app de Mercado Pago (o de tu banco), '
              'guardalo como imagen o sacale una captura, y cargalo acá. '
              'No hace falta la cámara.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _readingQr ? null : _loadQr,
              icon: _readingQr
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.image_outlined),
              label: const Text('Cargar mi QR desde una imagen'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos del negocio')),
      body: BlocConsumer<ShopBloc, ShopState>(
        listener: (context, state) {
          if (state is ShopLoaded) {
            _updateControllers(state.shop);
          } else if (state is ShopOperationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('¡Datos guardados!'),
                backgroundColor: Colors.green,
              ),
            );
            context.pop();
          } else if (state is ShopError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        buildWhen: (previous, current) =>
            current is ShopLoading || current is ShopLoaded,
        builder: (context, state) {
          if (state is ShopLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Información general',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: AppTheme.primaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Estos datos aparecerán en tus tickets impresos y digitales.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 24),
                  const InputLabel(text: 'Nombre del negocio'),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Ej: Almacén Don Pepe',
                    validator: AppValidators.required('Obligatorio'),
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'Dirección'),
                  _buildTextField(
                    controller: _address1Controller,
                    hint: 'Av. Siempre Viva 742',
                    validator: AppValidators.required('Obligatorio'),
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'Localidad (opcional)'),
                  _buildTextField(
                    controller: _address2Controller,
                    hint: 'Córdoba, Argentina',
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'Teléfono'),
                  _buildTextField(
                    controller: _phoneController,
                    hint: '+54 9 11 1234 5678',
                    keyboardType: TextInputType.phone,
                    validator: AppValidators.required('Obligatorio'),
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'Alias de Mercado Pago o CBU/CVU'),
                  _buildTextField(
                    controller: _aliasController,
                    hint: 'mi.alias.mp',
                  ),
                  const SizedBox(height: 15),
                  const InputLabel(text: 'QR de cobro'),
                  _buildQrSection(),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const InputLabel(text: 'Mensaje al pie del ticket'),
                      Text(
                        'Máx. 150 caracteres',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                  _buildTextField(
                    controller: _footerController,
                    hint: '¡Gracias por su compra!',
                    maxLines: 2,
                    maxLength: 60,
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: PrimaryButton(
        onPressed: _saveShop,
        icon: Icons.save,
        label: 'Guardar datos',
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      maxLength: maxLength,
      textCapitalization: TextCapitalization.words,
      validator: validator,
      decoration: InputDecoration(hintText: hint),
    );
  }
}
