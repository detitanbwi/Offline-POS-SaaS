import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class BluetoothDeviceModel {
  final String name;
  final String address;

  BluetoothDeviceModel({required this.name, required this.address});
}

class PrinterService {
  static final PrinterService instance = PrinterService._init();

  PrinterService._init();

  String? _connectedCashierAddress;
  String? _connectedKitchenAddress;

  Future<String?> _ensureBluetoothPermissions() async {
    if (!Platform.isAndroid) return null;

    final Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
    ].request();

    final connectStatus = statuses[Permission.bluetoothConnect]!;
    final scanStatus = statuses[Permission.bluetoothScan]!;

    if (connectStatus.isPermanentlyDenied || scanStatus.isPermanentlyDenied) {
      return 'Izin Bluetooth ditolak secara permanen. '
          'Buka Pengaturan HP → Aplikasi → Kasir POS → Izin → aktifkan "Perangkat di sekitar" / "Nearby devices".';
    }

    if (!connectStatus.isGranted || !scanStatus.isGranted) {
      return 'Izin Bluetooth belum diberikan. Silakan izinkan akses Bluetooth saat diminta.';
    }

    return null;
  }

  Future<bool> isBluetoothEnabled() async {
    if (!Platform.isAndroid) return true;
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      debugPrint('Error checking bluetooth status: $e');
      return false;
    }
  }

  Future<bool> checkBluetoothPermissions() async {
    if (!Platform.isAndroid) return true;
    try {
      // Meminta izin bluetoothConnect dan bluetoothScan untuk Android 12+ (Nearby Devices)
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();

      final bool connectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      final bool scanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;

      // Jika keduanya diberikan, maka true
      if (connectGranted && scanGranted) {
        return true;
      }

      // Fallback menggunakan metode bawaan library jika status tidak pasti
      final bool libResult = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      return libResult;
    } catch (e) {
      debugPrint('Error checking bluetooth permissions: $e');
      try {
        return await PrintBluetoothThermal.isPermissionBluetoothGranted;
      } catch (_) {
        return false;
      }
    }
  }

  Future<List<BluetoothDeviceModel>> scanDevices() async {
    if (!Platform.isAndroid) {
      // Return dummy devices for simulation on non-Android
      return [
        BluetoothDeviceModel(name: 'Simulator Printer Kasir (58mm)', address: '00:11:22:33:44:55'),
        BluetoothDeviceModel(name: 'Simulator Printer Dapur (58mm)', address: 'AA:BB:CC:DD:EE:FF'),
      ];
    }

    // Step 1: Request runtime permissions first
    final permissionError = await _ensureBluetoothPermissions();
    if (permissionError != null) {
      throw Exception(permissionError);
    }

    // Step 2: Check if Bluetooth hardware is enabled
    try {
      final bool hasPermission = await checkBluetoothPermissions();
      if (!hasPermission) {
        throw Exception('Izin Bluetooth (Nearby Devices / Perangkat Sekitar) ditolak. Mohon berikan izin di pengaturan aplikasi HP Anda.');
      }

      final bool enabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!enabled) {
        throw Exception('Bluetooth HP dalam keadaan mati. Silakan aktifkan Bluetooth HP Anda terlebih dahulu.');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('Bluetooth HP dalam keadaan mati')) {
        rethrow;
      }
      debugPrint('Error checking bluetooth enabled: $e');
      throw Exception('Gagal memeriksa status Bluetooth. Pastikan Bluetooth HP Anda aktif.');
    }

    // Step 3: Fetch paired (bonded) Bluetooth devices
    try {
      final List<BluetoothInfo> list = await PrintBluetoothThermal.pairedBluetooths;

      if (list.isEmpty) {
        throw Exception(
          'Tidak ditemukan perangkat Bluetooth yang dipasangkan (paired).\n\n'
          'Pastikan:\n'
          '1. Printer thermal sudah dinyalakan\n'
          '2. Printer sudah di-pair melalui Pengaturan Bluetooth HP\n'
          '3. Coba buka Pengaturan → Bluetooth → Pasangkan ulang printer',
        );
      }

      return list
          .map((d) => BluetoothDeviceModel(
                name: d.name.trim().isEmpty ? 'Printer Thermal (${d.macAdress})' : d.name,
                address: d.macAdress,
              ))
          .toList();
    } catch (e) {
      debugPrint('Error scanning devices: $e');
      rethrow;
    }
  }

  Future<bool> connectPrinter(String address, String type) async {
    if (!Platform.isAndroid) {
      debugPrint('Connecting to mock printer at $address for $type');
      if (type == 'cashier') {
        _connectedCashierAddress = address;
      } else {
        _connectedKitchenAddress = address;
      }
      return true;
    }

    // Ensure permissions before connecting
    final permissionError = await _ensureBluetoothPermissions();
    if (permissionError != null) {
      debugPrint('Permission error during connect: $permissionError');
      return false;
    }

    try {
      // Disconnect any existing connection first
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (isConnected) {
        await PrintBluetoothThermal.disconnect;
        // Small delay to let the BT stack settle
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final bool success = await PrintBluetoothThermal.connect(macPrinterAddress: address)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        debugPrint('Timeout connecting to Bluetooth printer $address');
        return false;
      });
      if (success) {
        if (type == 'cashier') {
          _connectedCashierAddress = address;
        } else {
          _connectedKitchenAddress = address;
        }
      }
      return success;
    } catch (e) {
      debugPrint('Error connecting printer: $e');
      return false;
    }
  }

  Future<bool> disconnectPrinter(String type) async {
    if (type == 'cashier') {
      _connectedCashierAddress = null;
    } else {
      _connectedKitchenAddress = null;
    }

    if (!Platform.isAndroid) return true;

    try {
      return await PrintBluetoothThermal.disconnect;
    } catch (e) {
      debugPrint('Error disconnecting printer: $e');
      return false;
    }
  }

  Future<bool> isConnected(String address) async {
    if (!Platform.isAndroid) {
      return _connectedCashierAddress == address || _connectedKitchenAddress == address;
    }
    try {
      final bool connected = await PrintBluetoothThermal.connectionStatus;
      return connected && (_connectedCashierAddress == address || _connectedKitchenAddress == address);
    } catch (e) {
      return false;
    }
  }

  Future<bool> printBytes(List<int> bytes, String targetAddress) async {
    if (!Platform.isAndroid) {
      debugPrint('--- SIMULASI PRINTING KE $targetAddress ---');
      debugPrint('Jumlah byte cetak: ${bytes.length}');
      debugPrint('-----------------------------------------');
      return true;
    }

    // Ensure permissions before printing
    final permissionError = await _ensureBluetoothPermissions();
    if (permissionError != null) {
      debugPrint('Permission error during print: $permissionError');
      return false;
    }

    try {
      final isCurrentlyConnected = await PrintBluetoothThermal.connectionStatus;
      final currentConnectedAddress = _connectedCashierAddress == targetAddress
          ? _connectedCashierAddress
          : _connectedKitchenAddress == targetAddress
              ? _connectedKitchenAddress
              : null;

      if (!isCurrentlyConnected || currentConnectedAddress != targetAddress) {
        // Disconnect existing if any
        if (isCurrentlyConnected) {
          await PrintBluetoothThermal.disconnect;
          await Future.delayed(const Duration(milliseconds: 300));
        }
        final connected = await PrintBluetoothThermal.connect(macPrinterAddress: targetAddress);
        if (!connected) {
          debugPrint('Failed to reconnect to printer $targetAddress');
          return false;
        }
        // Update local tracking
        if (_connectedCashierAddress == targetAddress || _connectedKitchenAddress == null) {
          _connectedCashierAddress = targetAddress;
        } else {
          _connectedKitchenAddress = targetAddress;
        }
      }

      final bool result = await PrintBluetoothThermal.writeBytes(bytes);
      return result;
    } catch (e) {
      debugPrint('Error printing bytes: $e');
      return false;
    }
  }
}
