import '../../../../core/data/hive_database.dart';
import '../../../../core/utils/printer_helper.dart';
import '../../domain/repositories/printer_repository.dart';

class PrinterRepositoryImpl implements PrinterRepository {
  final PrinterHelper _printerHelper = PrinterHelper();

  @override
  Future<bool> checkPermission() async {
    return true; // WiFi doesn't need special permissions generally
  }

  @override
  Future<bool> connect(String ipAddress) async {
    return await _printerHelper.connect(ipAddress);
  }

  @override
  Future<bool> disconnect() async {
    return await _printerHelper.disconnect();
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
    await _printerHelper
        .printText("Test Print\n\n$shopName\n\n----------------\n\n");
  }
}
