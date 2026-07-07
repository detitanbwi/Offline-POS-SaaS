import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/di/providers.dart';
import '../../../core/services/printer_service.dart';
import '../../printer/domain/models/printer_config.dart';
import '../../printer/domain/repositories/printer_repository.dart';

class PrinterState {
  final List<PrinterConfigModel> configuredPrinters;
  final List<BluetoothDeviceModel> scannedDevices;
  final bool isLoading;
  final bool isScanning;
  final String? errorMessage;

  PrinterState({
    this.configuredPrinters = const [],
    this.scannedDevices = const [],
    this.isLoading = false,
    this.isScanning = false,
    this.errorMessage,
  });

  PrinterState copyWith({
    List<PrinterConfigModel>? configuredPrinters,
    List<BluetoothDeviceModel>? scannedDevices,
    bool? isLoading,
    bool? isScanning,
    String? errorMessage,
  }) {
    return PrinterState(
      configuredPrinters: configuredPrinters ?? this.configuredPrinters,
      scannedDevices: scannedDevices ?? this.scannedDevices,
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      errorMessage: errorMessage,
    );
  }
}

class PrinterNotifier extends StateNotifier<PrinterState> {
  final PrinterRepository _repository;
  final PrinterService _printerService = PrinterService.instance;
  final _uuid = const Uuid();

  PrinterNotifier(this._repository) : super(PrinterState()) {
    loadPrinters();
  }

  Future<void> loadPrinters() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final list = await _repository.getPrintersConfig();
      
      // Verify connection status of each printer dynamically
      final List<PrinterConfigModel> verifiedList = [];
      for (var printer in list) {
        final connected = await _printerService.isConnected(printer.address);
        verifiedList.add(printer.copyWith(isConnected: connected));
      }
      
      state = state.copyWith(
        configuredPrinters: verifiedList,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat konfigurasi printer: $e',
      );
    }
  }

  Future<void> scanBluetoothDevices() async {
    state = state.copyWith(isScanning: true, errorMessage: null);
    try {
      await _printerService.checkBluetoothPermissions();
      final list = await _printerService.scanDevices();
      state = state.copyWith(
        scannedDevices: list,
        isScanning: false,
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        errorMessage: 'Gagal memindai bluetooth: $e',
      );
    }
  }

  Future<bool> saveAndConnectPrinter({
    required String name,
    required String address,
    required String type, // 'cashier' or 'kitchen'
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final connectSuccess = await _printerService.connectPrinter(address, type);
      if (!connectSuccess) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Gagal terhubung ke printer Bluetooth.',
        );
        return false;
      }

      final existing = await _repository.getPrinterConfigByType(type);
      
      final config = PrinterConfigModel(
        id: existing?.id ?? _uuid.v4(),
        name: name,
        address: address,
        type: type,
        isConnected: true,
        createdAt: existing?.createdAt ?? DateTime.now(),
      );

      await _repository.savePrinterConfig(config);
      await loadPrinters();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal menyimpan konfigurasi printer: $e',
      );
      return false;
    }
  }

  Future<bool> disconnectPrinter(String type) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _printerService.disconnectPrinter(type);
      
      final config = await _repository.getPrinterConfigByType(type);
      if (config != null) {
        await _repository.savePrinterConfig(config.copyWith(isConnected: false));
      }
      
      await loadPrinters();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memutuskan printer: $e',
      );
      return false;
    }
  }

  Future<bool> deletePrinter(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final config = state.configuredPrinters.firstWhere((p) => p.id == id);
      await _printerService.disconnectPrinter(config.type);
      await _repository.deletePrinterConfig(id);
      await loadPrinters();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal menghapus printer: $e',
      );
      return false;
    }
  }

  Future<bool> printBytes(PrinterConfigModel printer, List<int> bytes) async {
    try {
      return await _printerService.printBytes(bytes, printer.address);
    } catch (e) {
      state = state.copyWith(errorMessage: 'Gagal mencetak: $e');
      return false;
    }
  }
}

final printerNotifierProvider = StateNotifierProvider<PrinterNotifier, PrinterState>((ref) {
  final repository = ref.watch(printerRepositoryProvider);
  return PrinterNotifier(repository);
});
