import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:intl/intl.dart';
import 'printer_helper.dart'; // reuse EscPos constants

class BluetoothPrinterHelper {
  // Singleton
  static final BluetoothPrinterHelper _instance =
      BluetoothPrinterHelper._internal();
  factory BluetoothPrinterHelper() => _instance;
  BluetoothPrinterHelper._internal();

  BluetoothConnection? _connection;
  bool _isConnected = false;
  bool get isConnected => _isConnected && _connection != null;

  /// Returns a list of already-paired Bluetooth devices.
  Future<List<BluetoothDevice>> getPairedDevices() async {
    return await FlutterBluetoothSerial.instance.getBondedDevices();
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      _connection =
          await BluetoothConnection.toAddress(device.address)
              .timeout(const Duration(seconds: 10));
      _isConnected = true;
      return true;
    } catch (e) {
      _isConnected = false;
      return false;
    }
  }

  Future<bool> disconnect() async {
    try {
      await _connection?.finish();
      _connection = null;
      _isConnected = false;
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> printBytes(List<int> bytes) async {
    if (!isConnected) return;
    try {
      _connection!.output.add(Uint8List.fromList(bytes));
      await _connection!.output.allSent;
    } catch (_) {}
  }

  Future<void> printText(String text) async {
    if (!isConnected) return;
    await printBytes(text.codeUnits);
  }

  Future<void> printReceipt({
    required String shopName,
    required String address1,
    required String address2,
    required String phone,
    required List<Map<String, dynamic>> items,
    required double total,
    required String footer,
    String paymentLabel = '',
  }) async {
    if (!isConnected) return;

    List<int> bytes = [];

    bytes += EscPos.init;

    bytes += EscPos.alignCenter;
    bytes += EscPos.boldOn;
    bytes += EscPos.textLarge;
    bytes += shopName.codeUnits;
    bytes += EscPos.lineFeed;

    bytes += EscPos.textNormal;
    bytes += EscPos.boldOff;
    if (address1.isNotEmpty) {
      bytes += address1.codeUnits;
      bytes += EscPos.lineFeed;
    }
    if (address2.isNotEmpty) {
      bytes += address2.codeUnits;
      bytes += EscPos.lineFeed;
    }
    bytes += phone.codeUnits;
    bytes += EscPos.lineFeed;

    // Argentina time (UTC-3)
    final now = DateTime.now().toUtc().subtract(const Duration(hours: 3));
    String formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(now);
    bytes += formattedDate.codeUnits;
    bytes += EscPos.lineFeed;

    bytes += '--------------------------------'.codeUnits;
    bytes += EscPos.lineFeed;

    bytes += EscPos.alignLeft;
    bytes += 'Articulo        Precio  Total'.codeUnits;
    bytes += EscPos.lineFeed;
    bytes += '--------------------------------'.codeUnits;
    bytes += EscPos.lineFeed;

    for (var item in items) {
      String name = item['name'].toString();
      String qty = item['qty'].toString();
      String price = item['price'].toString();
      String totalItem = item['total'].toString();

      String prefix = '${qty}x $name';
      if (prefix.length > 16) prefix = prefix.substring(0, 16);
      String line = prefix.padRight(16) + price.padRight(8) + totalItem;
      bytes += line.codeUnits;
      bytes += EscPos.lineFeed;
    }

    bytes += '--------------------------------'.codeUnits;
    bytes += EscPos.lineFeed;

    if (paymentLabel.isNotEmpty) {
      bytes += EscPos.alignLeft;
      bytes += 'Pago: $paymentLabel'.codeUnits;
      bytes += EscPos.lineFeed;
    }

    bytes += EscPos.alignRight;
    bytes += EscPos.boldOn;
    bytes += 'TOTAL: $total'.codeUnits;
    bytes += EscPos.lineFeed;
    bytes += EscPos.boldOff;
    bytes += EscPos.lineFeed;

    bytes += EscPos.alignCenter;
    bytes += footer.codeUnits;
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;
    bytes += EscPos.lineFeed;

    await printBytes(bytes);
  }
}
