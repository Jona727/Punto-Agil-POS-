import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

/// Lo que se muestra al cobrar con Mercado Pago:
/// - el monto en grande (el QR del comercio no lleva el importe);
/// - el QR que el comercio cargó, o si no cargó uno, su alias para transferir.
class PaymentQrPanel extends StatelessWidget {
  final String qr;
  final String alias;
  final double total;

  const PaymentQrPanel({
    super.key,
    required this.qr,
    required this.alias,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final hasQr = qr.trim().isNotEmpty;
    final hasAlias = alias.trim().isNotEmpty;

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
          hasQr
              ? 'El cliente escanea y escribe este monto en su app'
              : 'El cliente transfiere este monto',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        if (hasQr) ...[
          SizedBox(
            width: 220,
            height: 220,
            // Cuadrados clásicos: los lectores de bancos y billeteras los leen
            // mejor que los módulos redondeados del estilo por defecto.
            child: PrettyQrView.data(
              data: qr.trim(),
              decoration: const PrettyQrDecoration(
                shape: PrettyQrSquaresSymbol(),
              ),
            ),
          ),
          if (hasAlias) ...[
            const SizedBox(height: 4),
            Text(
              alias,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ] else if (hasAlias)
          _AliasCard(alias: alias.trim())
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Cargá tu QR o tu alias en Ajustes → Datos del negocio para '
              'poder cobrar con Mercado Pago.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
          ),
        if (!hasQr && hasAlias) ...[
          const SizedBox(height: 6),
          Text(
            'Tip: cargá tu QR en Ajustes → Datos del negocio y se muestra acá.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ],
    );
  }
}

class _AliasCard extends StatelessWidget {
  final String alias;
  const _AliasCard({required this.alias});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F0FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alias',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                SelectableText(
                  alias,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copiar alias',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: alias));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Alias copiado')));
              }
            },
          ),
        ],
      ),
    );
  }
}
