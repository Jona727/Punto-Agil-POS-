import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Logo de Cobrá (opción A · Moneda): una "C" abierta con el punto del pago.
/// Se dibuja con código para no depender de imágenes ni de librerías de SVG.
/// Mantener igual a docs/logo/final_rounded.svg.
class CobraLogo extends StatelessWidget {
  final double size;

  /// false = cuadrado a sangre (sin esquinas redondeadas).
  final bool rounded;

  const CobraLogo({super.key, this.size = 64, this.rounded = true});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo de Cobrá',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _CobraLogoPainter(rounded: rounded)),
      ),
    );
  }
}

class _CobraLogoPainter extends CustomPainter {
  final bool rounded;
  const _CobraLogoPainter({required this.rounded});

  // Medidas del diseño original: lienzo de 256 x 256.
  static const double _base = 256;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _base, size.height / _base);

    // Fondo
    final background = Paint()..color = AppTheme.primaryColor;
    if (rounded) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, _base, _base), const Radius.circular(58)),
        background,
      );
    } else {
      canvas.drawRect(const Rect.fromLTWH(0, 0, _base, _base), background);
    }

    // "C": arco de 268° con la abertura a la derecha (46° arriba y abajo).
    const gap = 46 * math.pi / 180;
    final c = Path()
      ..addArc(
        Rect.fromCircle(center: const Offset(128, 128), radius: 66),
        -gap,
        -(2 * math.pi - 2 * gap),
      );
    canvas.drawPath(
      c,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round,
    );

    // Punto del pago
    canvas.drawCircle(const Offset(194, 128), 15,
        Paint()..color = AppTheme.secondaryColor);
  }

  @override
  bool shouldRepaint(_CobraLogoPainter old) => old.rounded != rounded;
}
