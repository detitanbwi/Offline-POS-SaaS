import '../models/printer_config.dart';

abstract class PrinterRepository {
  Future<List<PrinterConfigModel>> getPrintersConfig();
  Future<PrinterConfigModel?> getPrinterConfigByType(String type);
  Future<void> savePrinterConfig(PrinterConfigModel config);
  Future<void> deletePrinterConfig(String id);
  Future<void> updatePrinterConnectionStatus(String id, bool isConnected);
}
