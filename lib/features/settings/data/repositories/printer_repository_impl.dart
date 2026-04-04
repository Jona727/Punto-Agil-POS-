import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../../../core/utils/bluetooth_printer_helper.dart';
import '../../domain/repositories/printer_repository.dart';

class PrinterRepositoryImpl implements PrinterRepository {
  final PrinterHelper _wifiHelper = PrinterHelper();
  final BluetoothPrinterHelper _btHelper = BluetoothPrinterHelper();

  // ── Wi-Fi / LAN ──────────────────────────────────────────────────────────

  @override
  Future<bool> checkPermission() async {
    // Bluetooth permissions are required for Scanning and Connecting on Android 12+
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    // Location is often needed for scanning in older Android versions or some devices
    await Permission.location.request();

    return scan.isGranted && connect.isGranted;
  }

  @override
  Future<bool> connect(String ipAddress) async {
    return await _wifiHelper.connect(ipAddress);
  }

  @override
  Future<bool> disconnect() async {
    return await _wifiHelper.disconnect();
  }

  @override
  String? getSavedPrinterIp() {
    return HiveDatabase.settingsBox.get('printer_ip');
  }

  @override
  String? getSavedPrinterName() {
    return HiveDatabase.settingsBox.get('printer_name');
  }

  @override
  Future<void> savePrinterData(String ip, String name) async {
    await HiveDatabase.settingsBox.put('printer_ip', ip);
    await HiveDatabase.settingsBox.put('printer_name', name);
  }

  @override
  Future<void> clearSavedPrinter() async {
    await HiveDatabase.settingsBox.delete('printer_ip');
    await HiveDatabase.settingsBox.delete('printer_name');
  }

  @override
  Future<void> testPrint(String shopName) async {
    await _wifiHelper
        .printText("Test Print\n\n$shopName\n\n----------------\n\n");
  }

  // ── Bluetooth ─────────────────────────────────────────────────────────────

  @override
  Future<List<BluetoothDevice>> getPairedBluetoothDevices() async {
    return await _btHelper.getPairedDevices();
  }

  @override
  Future<bool> connectBluetooth(BluetoothDevice device) async {
    return await _btHelper.connect(device);
  }

  @override
  Future<bool> disconnectBluetooth() async {
    return await _btHelper.disconnect();
  }

  @override
  String? getSavedBluetoothAddress() {
    return HiveDatabase.settingsBox.get('printer_bt_address');
  }

  @override
  String? getSavedBluetoothName() {
    return HiveDatabase.settingsBox.get('printer_bt_name');
  }

  @override
  Future<void> saveBluetoothDevice(String address, String name) async {
    await HiveDatabase.settingsBox.put('printer_bt_address', address);
    await HiveDatabase.settingsBox.put('printer_bt_name', name);
  }

  @override
  Future<void> clearSavedBluetooth() async {
    await HiveDatabase.settingsBox.delete('printer_bt_address');
    await HiveDatabase.settingsBox.delete('printer_bt_name');
  }

  @override
  Future<void> testPrintBluetooth(String shopName) async {
    await _btHelper
        .printText("Test Print\n\n$shopName\n\n----------------\n\n");
  }

  // ── Preferences ────────────────────────────────────────────────────────────

  @override
  String getPreferredPrinterType() {
    return HiveDatabase.settingsBox.get('preferred_printer_type') ?? 'none';
  }

  @override
  Future<void> savePreferredPrinterType(String type) async {
    await HiveDatabase.settingsBox.put('preferred_printer_type', type);
  }
}
