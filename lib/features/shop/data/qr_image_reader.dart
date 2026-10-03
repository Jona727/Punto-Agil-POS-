import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/payment_qr.dart';

/// Resultado de elegir una imagen y leer el QR que contiene.
class QrReadResult {
  /// Contenido del QR; null si se canceló o falló.
  final String? payload;

  /// Mensaje para el comercio cuando falló; null si se canceló o salió bien.
  final String? error;

  const QrReadResult.ok(String this.payload) : error = null;
  const QrReadResult.cancelled() : payload = null, error = null;
  const QrReadResult.failed(String this.error) : payload = null;

  bool get isCancelled => payload == null && error == null;
}

abstract class QrImageReader {
  Future<QrReadResult> pickAndRead();
}

/// Elige una imagen de la galería (no usa la cámara) y lee el QR que tiene.
class GalleryQrImageReader implements QrImageReader {
  @override
  Future<QrReadResult> pickAndRead() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return const QrReadResult.cancelled();

      final scanner = MobileScannerController();
      try {
        final capture = await scanner.analyzeImage(picked.path);
        final values = (capture?.barcodes ?? const <Barcode>[])
            .map((b) => b.rawValue?.trim() ?? '')
            .where((v) => v.isNotEmpty)
            .toList();
        if (values.isEmpty) {
          return const QrReadResult.failed(
            'No encontramos un QR en esa imagen. Probá con una captura más '
            'clara, donde el QR se vea completo.',
          );
        }
        // Si la imagen trae varios, se prefiere el que parece QR de cobro.
        final best = values.firstWhere(
          looksLikePaymentQr,
          orElse: () => values.first,
        );
        if (!isUsablePaymentQr(best)) {
          return const QrReadResult.failed(
            'Ese QR es demasiado largo para ser un QR de cobro.',
          );
        }
        return QrReadResult.ok(best);
      } finally {
        await scanner.dispose();
      }
    } catch (_) {
      return const QrReadResult.failed(
        'No se pudo leer la imagen. Probá de nuevo con otra captura.',
      );
    }
  }
}
