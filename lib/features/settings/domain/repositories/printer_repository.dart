import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

abstract class PrinterRepository {
  // ── Wi-Fi / LAN ──────────────────────────────────────────────────────────
  Future<bool> checkPermission();
  Future<bool> connect(String ipAddress);
  Future<bool> disconnect();
  String? getSavedPrinterIp();
  String? getSavedPrinterName();
  Future<void> savePrinterData(String ip, String name);
  Future<void> clearSavedPrinter();
  Future<void> testPrint(String shopName);

  // ── Bluetooth ─────────────────────────────────────────────────────────────
  Future<List<BluetoothDevice>> getPairedBluetoothDevices();
  Future<bool> connectBluetooth(BluetoothDevice device);
  Future<bool> disconnectBluetooth();
  String? getSavedBluetoothAddress();
  String? getSavedBluetoothName();
  Future<void> saveBluetoothDevice(String address, String name);
  Future<void> clearSavedBluetooth();
  Future<void> testPrintBluetooth(String shopName);
}
