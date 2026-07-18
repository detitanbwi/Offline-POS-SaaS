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

    try {
      final bool hasPermission = await checkBluetoothPermissions();
      if (!hasPermission) {
        throw Exception('Izin Bluetooth (Nearby Devices / Perangkat Sekitar) ditolak. Mohon berikan izin di pengaturan aplikasi HP Anda.');
      }

      final bool enabled = await PrintBluetoothThermal.bluetoothEnabled;
      if (!enabled) {
        throw Exception('Bluetooth HP dalam keadaan mati. Silakan aktifkan Bluetooth HP Anda.');
      }

      final List<BluetoothInfo> list = await PrintBluetoothThermal.pairedBluetooths;
      return list
          .map((d) => BluetoothDeviceModel(
                name: d.name.isEmpty ? 'Printer Thermal (Perangkat Bluetooth)' : d.name,
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

    try {
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      if (isConnected) {
        await PrintBluetoothThermal.disconnect;
      }

      final bool success = await PrintBluetoothThermal.connect(macPrinterAddress: address)
          .timeout(const Duration(seconds: 4), onTimeout: () {
            debugPrint('Connection attempt timed out for $address');
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

    try {
      final isConnected = await PrintBluetoothThermal.connectionStatus;
      final currentConnectedAddress = _connectedCashierAddress == targetAddress 
          ? _connectedCashierAddress 
          : _connectedKitchenAddress == targetAddress 
              ? _connectedKitchenAddress 
              : null;
              
      if (!isConnected || currentConnectedAddress != targetAddress) {
        final connected = await PrintBluetoothThermal.connect(macPrinterAddress: targetAddress)
            .timeout(const Duration(seconds: 4), onTimeout: () {
              debugPrint('Connection attempt timed out during printBytes for $targetAddress');
              return false;
            });
        if (!connected) return false;
      }

      final bool result = await PrintBluetoothThermal.writeBytes(bytes);
      return result;
    } catch (e) {
      debugPrint('Error printing bytes: $e');
      return false;
    }
  }
}
