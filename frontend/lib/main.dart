import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frontend/services/hardware_service.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';
import 'package:crypto/crypto.dart';
import 'screens/login_screen.dart';
import 'screens/pin_screen.dart';
import 'services/secure_storage_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getInitialRoute() async {
    final storage = SecureStorageService();
    final savedPin = await storage.getLocalPIN();
    
    if (savedPin != null && savedPin.isNotEmpty) {
      return const PinScreen(isSetup: false);
    } else {
      return const LoginScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Offline SaaS License Simulator',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF002B93),
          primary: const Color(0xFF002B93),
          secondary: const Color(0xFFCC5900),
          error: const Color(0xFFD32F2F),
        ),
        cardTheme: const CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialRoute(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.data ?? const LoginScreen();
        },
      ),
    );
  }
}

enum AppLicenseStatus {
  notActivated,
  active,
  deviceCloned,
  expired,
  timeTampered,
  offlineLimitExceeded,
}

class LicenseHomeScreen extends StatefulWidget {
  const LicenseHomeScreen({super.key});

  @override
  State<LicenseHomeScreen> createState() => _LicenseHomeScreenState();
}

class _LicenseHomeScreenState extends State<LicenseHomeScreen> {
  final TextEditingController _licenseKeyController = TextEditingController();
  String _realDeviceId = "DEVICE-MOCK-REAL-99"; 
  
  String _currentDeviceId = "DEVICE-MOCK-REAL-99";
  DateTime _currentSystemTime = DateTime.now();
  Timer? _systemClockTimer;

  String _dbLicenseKey = "";
  String _dbEncryptedToken = "";
  String _dbLastTransactionTime = "";

  AppLicenseStatus _validationStatus = AppLicenseStatus.notActivated;
  String _statusMessage = "";
  bool _isLoading = false;

  String hashPIN(String pin) {
    var bytes = utf8.encode(pin); 
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  final String _serverBaseUrl = "https://demo2.wirodev.com";

  @override
  void initState() {
    super.initState();
    _initDeviceAndLoad();
    _startSystemClock();
  }

  Future<void> _initDeviceAndLoad() async {
    try {
      final realId = await HardwareService().getDeviceId();
      setState(() {
        _realDeviceId = realId;
        _currentDeviceId = realId;
      });
    } catch (e) {
      // Fallback is already initialized
    }
    await _loadFromDatabase();
    // Silent sync on startup if internet is available
    _syncBackgroundSilent();
  }

  @override
  void dispose() {
    _systemClockTimer?.cancel();
    _licenseKeyController.dispose();
    super.dispose();
  }

  void _startSystemClock() {
    _systemClockTimer?.cancel();
    _systemClockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentSystemTime = _currentSystemTime.add(const Duration(seconds: 1));
      });
      // Try background sync every 5 minutes (300 seconds)
      if (timer.tick % 300 == 0) {
        _syncBackgroundSilent();
      }
    });
  }

  Future<bool> _hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _syncBackgroundSilent() async {
    if (_dbLicenseKey.isEmpty) return;
    
    final bool online = await _hasInternetAccess();
    if (!online) return;

    try {
      final storage = SecureStorageService();
      final onlineToken = await storage.getOnlineToken(); 

      final response = await http.post(
        Uri.parse("$_serverBaseUrl/api/activate"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $onlineToken"
        },
        body: jsonEncode({
          "license_key": _dbLicenseKey,
          "device_id": _currentDeviceId,
        }),
      ).timeout(const Duration(seconds: 5));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final String encryptedToken = data['offline_token'];

        await DatabaseHelper.instance.updateLicenseInfo(
          licenseKey: _dbLicenseKey,
          encryptedToken: encryptedToken,
          lastTransactionTime: _currentSystemTime.toIso8601String(),
        );
        
        await storage.saveTokens(onlineToken: onlineToken ?? '', offlineToken: encryptedToken);
        
        final info = await DatabaseHelper.instance.getLicenseInfo();
        if (info != null) {
          setState(() {
            _dbLicenseKey = info['license_key'] ?? "";
            _dbEncryptedToken = info['encrypted_token'] ?? "";
            _dbLastTransactionTime = info['last_transaction_time'] ?? "";
          });
          validateOfflineAccess(_dbEncryptedToken).then(_updateStatus);
        }
      }
    } catch (_) {
      // Silent ignore
    }
  }

  Future<void> _loadFromDatabase() async {
    final info = await DatabaseHelper.instance.getLicenseInfo();
    if (info != null) {
      setState(() {
        _dbLicenseKey = info['license_key'] ?? "";
        _dbEncryptedToken = info['encrypted_token'] ?? "";
        _dbLastTransactionTime = info['last_transaction_time'] ?? "";
      });
      validateOfflineAccess(_dbEncryptedToken).then((status) {
        setState(() {
          _validationStatus = status;
          switch (status) {
            case AppLicenseStatus.active:
              _statusMessage = "APLIKASI AKTIF - Aman Digunakan Offline";
              break;
            case AppLicenseStatus.offlineLimitExceeded:
              _statusMessage = "MASA OFFLINE HABIS: Wajib online untuk sinkronisasi lisensi!";
              break;
            case AppLicenseStatus.expired:
              _statusMessage = "MASA AKTIF HABIS: Silakan Perpanjang Langganan.";
              break;
            case AppLicenseStatus.timeTampered:
              _statusMessage = "ASET AMAN: Terdeteksi Kecurangan Manipulasi Jam!";
              break;
            case AppLicenseStatus.deviceCloned:
              _statusMessage = "APLIKASI TERKUNCI: Perangkat Kloning Terdeteksi!";
              break;
            case AppLicenseStatus.notActivated:
              _statusMessage = "Aplikasi belum diaktivasi. Masukkan Key Lisensi Anda.";
              break;
          }
        });
      });
    }
  }

  String _decodeBase64Url(String str) {
    String output = str.replaceAll('-', '+').replaceAll('_', '/');
    switch (output.length % 4) {
      case 0:
        break;
      case 2:
        output += '==';
        break;
      case 3:
        output += '=';
        break;
      default:
        throw Exception('Illegal base64url string!');
    }
    return utf8.decode(base64.decode(output));
  }

  Future<AppLicenseStatus> validateOfflineAccess(String offlineToken) async {
    try {
      if (offlineToken.isEmpty) {
        debugPrint("[Validation] Fail: Token is empty");
        return AppLicenseStatus.notActivated;
      }
      
      List<String> parts = offlineToken.split('.');
      String boundDeviceId = "";
      int expiresTimestamp = 0;

      if (parts.length == 3) {
        // Standard JWT layout (New Format)
        const String secretKey = 'SIMULATION_ONLY_NOT_FOR_PRODUCTION_SECRET_KEY_9921';
        final keyBytes = utf8.encode(secretKey);
        final dataBytes = utf8.encode('${parts[0]}.${parts[1]}');
        final hmac = Hmac(sha256, keyBytes);
        final digest = hmac.convert(dataBytes);

        final String expectedSignature = base64Url.encode(digest.bytes).replaceAll('=', '');
        final String actualSignature = parts[2].replaceAll('=', '');

        if (expectedSignature != actualSignature) {
          debugPrint("[Validation] Fail: JWT Signature mismatch. Expected: $expectedSignature, Actual: $actualSignature");
          return AppLicenseStatus.notActivated; // Compromised
        }

        Map<String, dynamic> payload = jsonDecode(_decodeBase64Url(parts[1]));
        boundDeviceId = payload['android_id'];
        expiresTimestamp = payload['exp'];
      } else {
        // Backward Compatibility: Decode the old format
        String decoded = utf8.decode(base64Decode(offlineToken));
        int lastDot = decoded.lastIndexOf('.');
        if (lastDot == -1) {
          debugPrint("[Validation] Fail: Old format missing separator dot");
          return AppLicenseStatus.notActivated;
        }

        String payloadStr = decoded.substring(0, lastDot);
        Map<String, dynamic> payload = jsonDecode(payloadStr);
        boundDeviceId = payload['device_id'] ?? "";
        expiresTimestamp = payload['expires_at'] ?? 0;
      }

      String currentDeviceId = _currentDeviceId;
      
      if (currentDeviceId != boundDeviceId) {
         debugPrint("[Validation] Fail: Device ID mismatch. Current: $currentDeviceId, Bound: $boundDeviceId");
         return AppLicenseStatus.deviceCloned;
      }

      // Check 7-day offline limit
      if (_dbLastTransactionTime.isNotEmpty) {
        final DateTime lastTransaction = DateTime.parse(_dbLastTransactionTime);
        if (_currentSystemTime.difference(lastTransaction).inDays >= 7) {
           debugPrint("[Validation] Fail: Offline limit exceeded (>= 7 days since last sync)");
           return AppLicenseStatus.offlineLimitExceeded;
        }
      }

      int currentTimestamp = _currentSystemTime.millisecondsSinceEpoch ~/ 1000;
      if (currentTimestamp > expiresTimestamp) {
         debugPrint("[Validation] Fail: Token expired. Current: $currentTimestamp, Expires: $expiresTimestamp");
         return AppLicenseStatus.expired;
      }

      if (_dbLastTransactionTime.isNotEmpty) {
        final DateTime lastTransaction = DateTime.parse(_dbLastTransactionTime);
        if (_currentSystemTime.isBefore(lastTransaction)) {
           debugPrint("[Validation] Fail: Time tampered. Current clock $_currentSystemTime is before last transaction $lastTransaction");
           return AppLicenseStatus.timeTampered;
        }
      }

      DatabaseHelper.instance.updateLicenseInfo(
        licenseKey: _dbLicenseKey,
        encryptedToken: _dbEncryptedToken,
        lastTransactionTime: _currentSystemTime.toIso8601String(),
      );
      _dbLastTransactionTime = _currentSystemTime.toIso8601String();

      debugPrint("[Validation] Success!");
      return AppLicenseStatus.active; 
    } catch (e, stack) {
      debugPrint("[Validation] Exception during check: $e\n$stack");
      return AppLicenseStatus.notActivated; 
    }
  }

  Future<void> _activateLicense() async {
    final key = _licenseKeyController.text.trim();
    if (key.isEmpty) {
      _showSnackbar("Harap masukkan License Key!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storage = SecureStorageService();
      // Gunakan getOnlineToken()
      final onlineToken = await storage.getOnlineToken(); 

      final response = await http.post(
        Uri.parse("$_serverBaseUrl/api/activate"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $onlineToken" 
        },
        body: jsonEncode({
          "license_key": key,
          "device_id": _currentDeviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final String encryptedToken = data['offline_token']; 

        await DatabaseHelper.instance.updateLicenseInfo(
          licenseKey: key,
          encryptedToken: encryptedToken,
          lastTransactionTime: _currentSystemTime.toIso8601String(),
        );
        
        await storage.saveTokens(onlineToken: onlineToken ?? '', offlineToken: encryptedToken);

        _showSnackbar("Aktivasi Server Berhasil!");
        _loadFromDatabase();
      } else {
        _showSnackbar("Aktivasi Gagal: ${data['message'] ?? 'Respons error server'}");
      }
    } catch (e) {
      _showSnackbar("Gagal menghubungi server. Pastikan server aktif dan online!");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncManual() async {
    if (_dbLicenseKey.isEmpty) {
      _showSnackbar("Belum ada lisensi untuk disinkronkan!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storage = SecureStorageService();
      final onlineToken = await storage.getOnlineToken(); 

      final response = await http.post(
        Uri.parse("$_serverBaseUrl/api/activate"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $onlineToken" // Otorisasi dibutuhkan route auth:sanctum
        },
        body: jsonEncode({
          "license_key": _dbLicenseKey,
          "device_id": _currentDeviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // Backend mengirimkan 'offline_token', bukan 'encrypted_token'
        final String encryptedToken = data['offline_token'];

        await DatabaseHelper.instance.updateLicenseInfo(
          licenseKey: _dbLicenseKey,
          encryptedToken: encryptedToken,
          lastTransactionTime: _currentSystemTime.toIso8601String(),
        );
        
        await storage.saveTokens(onlineToken: onlineToken ?? '', offlineToken: encryptedToken);

        _showSnackbar("Sinkronisasi manual berhasil!");
        _loadFromDatabase();
      } else {
        _showSnackbar("Sinkronisasi Gagal: ${data['message']}");
      }
    } catch (e) {
      _showSnackbar("Offline: Gagal terhubung ke server untuk sinkronisasi.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncManualLocked() async {
    if (_dbLicenseKey.isEmpty) {
      _showSnackbar("Belum ada lisensi untuk disinkronkan!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final storage = SecureStorageService();
      final onlineToken = await storage.getOnlineToken(); 

      // Connect to server with a 10-second timeout
      final response = await http.post(
        Uri.parse("$_serverBaseUrl/api/activate"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $onlineToken"
        },
        body: jsonEncode({
          "license_key": _dbLicenseKey,
          "device_id": _currentDeviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final String encryptedToken = data['offline_token'];

        await DatabaseHelper.instance.updateLicenseInfo(
          licenseKey: _dbLicenseKey,
          encryptedToken: encryptedToken,
          lastTransactionTime: _currentSystemTime.toIso8601String(),
        );
        
        await storage.saveTokens(onlineToken: onlineToken ?? '', offlineToken: encryptedToken);

        _showSnackbar("Sinkronisasi Berhasil! Aplikasi aktif kembali.");
        await _loadFromDatabase();
      } else {
        _showErrorDialog("Gagal Sinkronisasi", data['message'] ?? "Respon server tidak valid.");
      }
    } on TimeoutException catch (_) {
      _showErrorDialog("Koneksi Timeout", "Gagal terhubung ke server setelah 10 detik. Silakan periksa jaringan internet Anda.");
    } catch (e) {
      _showErrorDialog("Kesalahan Koneksi", "Gagal menghubungi server untuk sinkronisasi. Pastikan perangkat memiliki koneksi internet aktif.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _updateStatus(AppLicenseStatus status) {
    setState(() {
      _validationStatus = status;
      switch (status) {
        case AppLicenseStatus.active:
          _statusMessage = "APLIKASI AKTIF - Aman Digunakan Offline";
          break;
        case AppLicenseStatus.offlineLimitExceeded:
          _statusMessage = "MASA OFFLINE HABIS: Wajib online untuk sinkronisasi lisensi!";
          break;
        case AppLicenseStatus.expired:
          _statusMessage = "MASA AKTIF HABIS: Silakan Perpanjang Langganan.";
          break;
        case AppLicenseStatus.timeTampered:
          _statusMessage = "ASET AMAN: Terdeteksi Kecurangan Manipulasi Jam!";
          break;
        case AppLicenseStatus.deviceCloned:
          _statusMessage = "APLIKASI TERKUNCI: Perangkat Kloning Terdeteksi!";
          break;
        case AppLicenseStatus.notActivated:
          _statusMessage = "Aplikasi belum diaktivasi. Masukkan Key Lisensi Anda.";
          break;
      }
    });
  }

  void _simulateCloning() {
    setState(() {
      final randomNum = Random().nextInt(10000);
      _currentDeviceId = "DEVICE-CLONE-$randomNum";
    });
    validateOfflineAccess(_dbEncryptedToken).then(_updateStatus);
    _showSnackbar("Simulasi: ID Perangkat diubah (Kloning)!");
  }

  void _simulateTimeExpiry() {
    _systemClockTimer?.cancel();
    setState(() {
      _currentSystemTime = DateTime.now().add(const Duration(days: 32));
    });
    validateOfflineAccess(_dbEncryptedToken).then(_updateStatus);
    _showSnackbar("Simulasi: Jam dimajukan melewati masa aktif!");
  }

  void _simulateTimeTampering() {
    _systemClockTimer?.cancel();
    setState(() {
      if (_dbLastTransactionTime.isNotEmpty) {
        final DateTime lastTx = DateTime.parse(_dbLastTransactionTime);
        _currentSystemTime = lastTx.subtract(const Duration(hours: 2));
      } else {
        _currentSystemTime = DateTime.now().subtract(const Duration(days: 1));
      }
    });
    validateOfflineAccess(_dbEncryptedToken).then(_updateStatus);
    _showSnackbar("Simulasi: Jam dimundurkan (Time Tampering)!");
  }

  void _resetToNormal() {
    setState(() {
      _currentDeviceId = _realDeviceId;
      _currentSystemTime = DateTime.now();
    });
    _startSystemClock();
    validateOfflineAccess(_dbEncryptedToken).then(_updateStatus);
    _showSnackbar("Simulasi: Perangkat & Jam dikembalikan normal.");
  }

  void _clearLocalDatabase() async {
    await DatabaseHelper.instance.clearLicenseInfo();
    _licenseKeyController.clear();
    _loadFromDatabase();
    _showSnackbar("Data lokal di-reset.");
  }

  void _showSnackbar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
    );
  }

  Color _getStatusColor() {
    switch (_validationStatus) {
      case AppLicenseStatus.active:
        return const Color(0xFF10B981); 
      case AppLicenseStatus.deviceCloned:
        return const Color(0xFFEF4444); 
      case AppLicenseStatus.offlineLimitExceeded:
        return const Color(0xFFEF4444); 
      case AppLicenseStatus.expired:
        return const Color(0xFFCC5900); 
      case AppLicenseStatus.timeTampered:
        return const Color(0xFF7F1D1D); 
      case AppLicenseStatus.notActivated:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    final timeFormat = DateFormat('yyyy-MM-dd HH:i:ss').format(_currentSystemTime);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "SaaS Offline-First Demo App",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadFromDatabase,
            tooltip: "Muat Ulang Status",
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.white),
            onPressed: _clearLocalDatabase,
            tooltip: "Hapus Lisensi Lokal",
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFFF4F6F9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "STATUS AKTIVASI APLIKASI",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              
              if (_validationStatus == AppLicenseStatus.offlineLimitExceeded) ...[
                Card(
                  elevation: 4,
                  color: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: Colors.red.shade200, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cloud_off_rounded,
                              size: 48,
                              color: Colors.red.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "APLIKASI TERKUNCI",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF7F1D1D),
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Batas waktu offline maksimal (7 hari) telah tercapai. Anda wajib melakukan sinkronisasi dengan server untuk melanjutkan penggunaan aplikasi.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade800,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _isLoading
                            ? const Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 12),
                                  Text(
                                    "Menghubungi server...",
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                  )
                                ],
                              )
                            : ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFD32F2F),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 2,
                                ),
                                icon: const Icon(Icons.sync_rounded),
                                label: const Text(
                                  "SINKRONISASI SEKARANG",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _syncManualLocked,
                              ),
                      ],
                    ),
                  ),
                ),
              ] else if (_validationStatus == AppLicenseStatus.notActivated) ...[
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.vpn_key_outlined, size: 28, color: Theme.of(context).colorScheme.secondary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Aktivasi Diperlukan",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    "Masukkan lisensi dari dashboard web Laravel Anda.",
                                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _licenseKeyController,
                          inputFormatters: [
                            LicenseKeyFormatter(),
                          ],
                          decoration: InputDecoration(
                            labelText: "License Key",
                            hintText: "LIC-XXXX-XXXX-XXXX",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: const Icon(Icons.key),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.cloud_upload_outlined),
                                label: const Text("Aktivasi Melalui Server", style: TextStyle(fontWeight: FontWeight.bold)),
                                onPressed: _activateLicense,
                              ),
                      ],
                    ),
                  ),
                ),
                if (_dbEncryptedToken.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Card(
                    elevation: 2,
                    color: Colors.amber.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "Lisensi Tersimpan (Gagal Validasi)",
                                style: TextStyle(
                                  color: Colors.amber.shade900,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "License Key: $_dbLicenseKey",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Offline Token:",
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            _dbEncryptedToken,
                            style: const TextStyle(
                              fontFamily: 'Courier',
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ] else ...[
                Card(
                  elevation: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          statusColor,
                          statusColor.withOpacity(0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.white24,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.security,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "VALIDASI KEAMANAN",
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  Text(
                                    _statusMessage,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(color: Colors.white24, height: 24),
                        Text(
                          "Lisensi Aktif: $_dbLicenseKey",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontFamily: 'Courier',
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Token Aktif (JWT):",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _dbEncryptedToken,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontFamily: 'Courier',
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text("Device ID Terbaca saat ini:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _currentDeviceId,
                            style: TextStyle(
                              fontFamily: 'Courier', 
                              fontWeight: FontWeight.bold, 
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text("Waktu Sistem saat ini:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeFormat,
                            style: const TextStyle(fontFamily: 'Courier', fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.sync),
                      label: const Text("Tombol Sinkronisasi Manual", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      onPressed: _syncManual,
                    ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Text(
                    "PANEL KONTROL SIMULASI",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 1, 
                      color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.secondary,
                    width: 2.0,
                  ),
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Manipulasi parameter sistem di bawah ini untuk melihat respon pertahanan offline aplikasi.",
                      style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 16),
                    
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.copy_all),
                      label: const Text("Simulasikan Kloning Aplikasi"),
                      onPressed: _simulateCloning,
                    ),
                    const SizedBox(height: 10),
                    
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.hourglass_bottom),
                      label: const Text("Simulasikan Waktu Habis"),
                      onPressed: _simulateTimeExpiry,
                    ),
                    const SizedBox(height: 10),
                    
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.restore_page),
                      label: const Text("Simulasikan Mundurkan Jam"),
                      onPressed: _simulateTimeTampering,
                    ),
                    const SizedBox(height: 16),
                    
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.restart_alt),
                      label: const Text("Reset ke Normal", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _resetToNormal,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class LicenseKeyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.toUpperCase();
    String cleanText = text.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    if (cleanText.length >= 3) {
      if (cleanText.substring(0, 3) != "LIC") {
        cleanText = "LIC$cleanText";
      }
    } else {
      if (cleanText.isNotEmpty && !("LIC".startsWith(cleanText))) {
        cleanText = "LIC$cleanText";
      }
    }
    
    String formatted = "";
    if (cleanText.isNotEmpty) {
      formatted += cleanText.substring(0, min(cleanText.length, 3));
    }
    if (cleanText.length > 3) {
      formatted += "-${cleanText.substring(3, min(cleanText.length, 7))}";
    }
    if (cleanText.length > 7) {
      formatted += "-${cleanText.substring(7, min(cleanText.length, 11))}";
    }
    if (cleanText.length > 11) {
      formatted += "-${cleanText.substring(11, min(cleanText.length, 15))}";
    }
    
    if (formatted.length > 18) {
      formatted = formatted.substring(0, 18);
    }
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}