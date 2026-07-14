import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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
      final bool result = await PrintBluetoothThermal.isPermissionBluetoothGranted;
      return result;
    } catch (e) {
      debugPrint('Error checking bluetooth permissions: $e');
      return false;
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

      final bool success = await PrintBluetoothThermal.connect(macPrinterAddress: address);
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
        final connected = await PrintBluetoothThermal.connect(macPrinterAddress: targetAddress);
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
