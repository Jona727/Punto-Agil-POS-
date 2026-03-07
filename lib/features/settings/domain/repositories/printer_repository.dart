abstract class PrinterRepository {
  Future<bool> checkPermission();
  Future<bool> connect(String ipAddress);
  Future<bool> disconnect();
  String? getSavedPrinterIp();
  String? getSavedPrinterName();
  Future<void> savePrinterData(String ip, String name);
  Future<void> clearSavedPrinter();
  Future<void> testPrint(String shopName);
}
