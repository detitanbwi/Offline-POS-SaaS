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
  final String? loadingType;
  final bool isInitialLoading;

  PrinterState({
    this.configuredPrinters = const [],
    this.scannedDevices = const [],
    this.isLoading = false,
    this.isScanning = false,
    this.errorMessage,
    this.loadingType,
    this.isInitialLoading = true,
  });

  PrinterState copyWith({
    List<PrinterConfigModel>? configuredPrinters,
    List<BluetoothDeviceModel>? scannedDevices,
    bool? isLoading,
    bool? isScanning,
    String? errorMessage,
    String? Function()? loadingType,
    bool? isInitialLoading,
  }) {
    return PrinterState(
      configuredPrinters: configuredPrinters ?? this.configuredPrinters,
      scannedDevices: scannedDevices ?? this.scannedDevices,
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      errorMessage: errorMessage,
      loadingType: loadingType != null ? loadingType() : this.loadingType,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
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
    state = state.copyWith(isLoading: true, loadingType: () => null, errorMessage: null);
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
        isInitialLoading: false,
        loadingType: () => null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isInitialLoading: false,
        loadingType: () => null,
        errorMessage: 'Gagal memuat konfigurasi printer: $e',
      );
    }
  }

  Future<void> scanBluetoothDevices() async {
    state = state.copyWith(isScanning: true, errorMessage: null);
    try {
      final list = await _printerService.scanDevices();
      state = state.copyWith(
        scannedDevices: list,
        isScanning: false,
      );
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      state = state.copyWith(
        isScanning: false,
        errorMessage: msg,
      );
    }
  }

  Future<bool> saveAndConnectPrinter({
    required String name,
    required String address,
    required String type, // 'cashier' or 'kitchen'
  }) async {
    print('[PrinterNotifier] saveAndConnectPrinter starting for $name ($address) type $type');
    state = state.copyWith(isLoading: true, loadingType: () => type, errorMessage: null);
    try {
      print('[PrinterNotifier] Calling connectPrinter...');
      final connectSuccess = await _printerService.connectPrinter(address, type);
      print('[PrinterNotifier] connectPrinter result: $connectSuccess');
      
      print('[PrinterNotifier] Getting existing config from repo...');
      final existing = await _repository.getPrinterConfigByType(type);
      print('[PrinterNotifier] Existing config: $existing');
      
      final config = PrinterConfigModel(
        id: existing?.id ?? _uuid.v4(),
        name: name,
        address: address,
        type: type,
        isConnected: connectSuccess,
        createdAt: existing?.createdAt ?? DateTime.now(),
      );

      print('[PrinterNotifier] Saving config to repo: ${config.toMap()}');
      await _repository.savePrinterConfig(config);
      print('[PrinterNotifier] Config saved successfully');
      
      print('[PrinterNotifier] Loading printers list...');
      await loadPrinters();
      print('[PrinterNotifier] Printers list loaded');

      if (!connectSuccess) {
        state = state.copyWith(
          errorMessage: 'Printer berhasil disimpan, tetapi tidak terhubung saat ini. Sistem akan mencoba terhubung otomatis ketika Anda mencetak.',
        );
      }
      
      print('[PrinterNotifier] saveAndConnectPrinter finished with true');
      return true;
    } catch (e, stack) {
      print('[PrinterNotifier] Exception in saveAndConnectPrinter: $e');
      print('[PrinterNotifier] Stacktrace: $stack');
      state = state.copyWith(
        isLoading: false,
        loadingType: () => null,
        errorMessage: 'Gagal menyimpan konfigurasi printer: $e',
      );
      return false;
    }
  }

  Future<bool> disconnectPrinter(String type) async {
    state = state.copyWith(isLoading: true, loadingType: () => type, errorMessage: null);
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
        loadingType: () => null,
        errorMessage: 'Gagal memutuskan printer: $e',
      );
      return false;
    }
  }

  Future<bool> deletePrinter(String id) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final config = state.configuredPrinters.firstWhere((p) => p.id == id);
      state = state.copyWith(isLoading: true, loadingType: () => config.type, errorMessage: null);
      await _printerService.disconnectPrinter(config.type);
      await _repository.deletePrinterConfig(id);
      await loadPrinters();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        loadingType: () => null,
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
