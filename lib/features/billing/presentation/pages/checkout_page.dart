import 'dart:async';

import 'package:cobra/core/widgets/primary_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import '../../../shop/presentation/bloc/shop_bloc.dart';
import '../../domain/entities/payment_method.dart';
import '../bloc/billing_bloc.dart';

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  Timer? _resetTimer;
  int _countdown = 5;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _startResetCountdown() {
    setState(() => _countdown = 5);
    _resetTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _countdown--);
      if (_countdown <= 0) {
        timer.cancel();
        _resetAndGoHome();
      }
    });
  }

  void _resetAndGoHome() {
    _resetTimer?.cancel();
    context.read<BillingBloc>().add(ClearCartEvent());
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    const borderColor = Color(0xFFE5E5EA);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) return;
        _resetAndGoHome();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Cobrar',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.chevron_left,
              size: 28,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: _resetAndGoHome,
          ),
        ),
        body: BlocConsumer<BillingBloc, BillingState>(
          listener: (context, state) {
            if (state.printSuccess) {
              _startResetCountdown();
            }
          },
          builder: (context, billingState) {
            return BlocBuilder<ShopBloc, ShopState>(
              builder: (context, shopState) {
                String paymentAlias = '';

                if (shopState is ShopLoaded) {
                  paymentAlias = shopState.shop.paymentAlias;
                }

                // Build MercadoPago deep-link (offline-safe: URL is generated locally)
                final mpUrl = paymentAlias.isNotEmpty
                    ? 'https://link.mercadopago.com.ar/$paymentAlias'
                    : '';

                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Column(
                          children: [
                            // Items table
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Table(
                                  border: const TableBorder(
                                    horizontalInside: BorderSide(
                                      color: borderColor,
                                    ),
                                    bottom: BorderSide(color: borderColor),
                                  ),
                                  children: [
                                    TableRow(
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF8FAFC),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: borderColor,
                                          ),
                                        ),
                                      ),
                                      children: [
                                        _buildHeaderCell(
                                          'Producto',
                                          TextAlign.left,
                                        ),
                                        _buildHeaderCell(
                                          'Precio',
                                          TextAlign.right,
                                        ),
                                        _buildHeaderCell(
                                          'Total',
                                          TextAlign.right,
                                        ),
                                      ],
                                    ),
                                    ...billingState.cartItems.map((item) {
                                      return TableRow(
                                        children: [
                                          _buildDataCell(
                                            '${item.quantity} x ${item.product.name}',
                                            TextAlign.left,
                                          ),
                                          _buildDataCell(
                                            '\$${item.product.price.toStringAsFixed(2)}',
                                            TextAlign.right,
                                            isSubtitle: true,
                                          ),
                                          _buildDataCell(
                                            '\$${item.total.toStringAsFixed(2)}',
                                            TextAlign.right,
                                            isBold: true,
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const SizedBox(height: 120),
                          ],
                        ),
                      ),
                    ),

                    // Bottom Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(24),
                          right: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              children: [
                                const SizedBox(height: 8),

                                // Medio de pago
                                _PaymentMethodSelector(
                                  selected: billingState.paymentMethod,
                                  enabled: !billingState.isSaleRegistered,
                                  onSelected: (m) => context
                                      .read<BillingBloc>()
                                      .add(SelectPaymentMethodEvent(m)),
                                ),
                                const SizedBox(height: 12),

                                // El QR de Mercado Pago solo se muestra si paga con Mercado Pago
                                if (billingState.paymentMethod ==
                                    PaymentMethod.mercadoPago)
                                  _MercadoPagoQr(
                                    url: mpUrl,
                                    alias: paymentAlias,
                                    total: billingState.totalAmount,
                                  ),

                                const SizedBox(height: 15),

                                // Venta registrada (todavía sin imprimir)
                                if (billingState.isSaleRegistered &&
                                    !billingState.printSuccess)
                                  Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.green[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      '✅ Venta registrada · ${billingState.paymentMethod.label}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.green[800],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),

                                // Countdown banner (shown after print)
                                if (billingState.printSuccess)
                                  Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.green[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '✅ Impreso · Nueva venta en ${_countdown}s',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.green[800],
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: _resetAndGoHome,
                                          style: TextButton.styleFrom(
                                            padding: EdgeInsets.zero,
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          child: Text(
                                            'Ahora →',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Total row
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'TOTAL A COBRAR',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[400],
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    Text(
                                      '\$${billingState.totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: -0.5,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!billingState.isSaleRegistered)
                            PrimaryButton(
                              onPressed: billingState.cartItems.isEmpty
                                  ? null
                                  : () => context.read<BillingBloc>().add(
                                      const ConfirmSaleEvent(),
                                    ),
                              label:
                                  billingState.paymentMethod ==
                                      PaymentMethod.mercadoPago
                                  ? 'Confirmar pago recibido'
                                  : 'Registrar cobro',
                              icon: Icons.check_circle_outline,
                            )
                          else ...[
                            PrimaryButton(
                              onPressed: billingState.printSuccess
                                  ? null
                                  : () {
                                      if (shopState is ShopLoaded) {
                                        context.read<BillingBloc>().add(
                                          PrintReceiptEvent(
                                            shopName: shopState.shop.name,
                                            address1:
                                                shopState.shop.addressLine1,
                                            address2:
                                                shopState.shop.addressLine2,
                                            phone: shopState.shop.phoneNumber,
                                            footer: shopState.shop.footerText,
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'No se cargaron los datos del negocio',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                              label: billingState.printSuccess
                                  ? 'Impreso ✅'
                                  : 'Imprimir ticket',
                              icon: Icons.print,
                              isLoading: billingState.isPrinting,
                            ),
                            if (!billingState.printSuccess) ...[
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: billingState.isPrinting
                                    ? null
                                    : _resetAndGoHome,
                                child: const Text('Nueva venta sin ticket'),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String text, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text.toUpperCase(),
        textAlign: align,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildDataCell(
    String text,
    TextAlign align, {
    bool isBold = false,
    bool isSubtitle = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: isSubtitle ? 12 : 14,
          fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
          color: isSubtitle ? Colors.grey[500] : Colors.black87,
        ),
      ),
    );
  }
}

class _PaymentMethodSelector extends StatelessWidget {
  final PaymentMethod selected;
  final bool enabled;
  final ValueChanged<PaymentMethod> onSelected;

  const _PaymentMethodSelector({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final method in PaymentMethod.values)
          ChoiceChip(
            label: Text(method.label),
            selected: method == selected,
            onSelected: enabled ? (_) => onSelected(method) : null,
          ),
      ],
    );
  }
}

/// QR fijo del comercio. No lleva el monto: se muestra grande para que el
/// cajero se lo diga al cliente, que lo escribe en su app.
class _MercadoPagoQr extends StatelessWidget {
  final String url;
  final String alias;
  final double total;

  const _MercadoPagoQr({
    required this.url,
    required this.alias,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Falta tu alias de Mercado Pago. Cargalo en Ajustes → Datos del negocio '
          'para mostrar el QR.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13),
        ),
      );
    }
    return Column(
      children: [
        Text(
          'Cobrar \$${total.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'El cliente escanea y escribe este monto en su app',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        SizedBox(width: 180, height: 180, child: PrettyQrView.data(data: url)),
        const SizedBox(height: 4),
        Text(alias, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }
}
