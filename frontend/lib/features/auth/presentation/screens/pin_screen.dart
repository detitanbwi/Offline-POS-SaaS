import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:crypto/crypto.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/di/providers.dart';
import '../../../menu/presentation/screens/main_menu_screen.dart';
import '../../domain/models/auth_user.dart';
import '../providers/auth_providers.dart';

class PinScreen extends ConsumerStatefulWidget {
  final bool isSetup;
  const PinScreen({super.key, required this.isSetup});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _pinController = TextEditingController();
  final _usernameController = TextEditingController();
  String _errorMessage = '';

  String _hashPIN(String pin) {
    const salt = 'OfflinePOSSecureSalt_Sprint4_2026';
    var bytes = utf8.encode(pin + salt);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _submitPin() async {
    final pin = _pinController.text;
    if (pin.length < 4) {
      setState(() => _errorMessage = 'PIN minimal 4 digit!');
      return;
    }

    final username = _usernameController.text.trim();
    if (!widget.isSetup && username.isEmpty) {
      setState(() => _errorMessage = 'Username harus diisi!');
      return;
    }

    final hashedPin = _hashPIN(pin);

    final storage = ref.read(secureStorageServiceProvider);
    if (widget.isSetup) {
      await storage.saveLocalPIN(hashedPin);
      ref.read(authSessionProvider.notifier).state = const AuthUser(
        id: 'owner',
        nama: 'Pemilik Toko',
        role: 'pemilik',
      );
      if (!mounted) return;
      AppSnackbar.showSuccess(context, 'PIN Keamanan berhasil dibuat!');
      _goToMainMenu();
    } else {
      // 1. Check if login is owner
      final savedOwnerUsername = await storage.getOwnerUsername() ?? 'owner';
      final lowerUser = username.trim().toLowerCase();
      final lowerOwner = savedOwnerUsername.trim().toLowerCase();

      final isOwnerMatch = lowerUser == lowerOwner ||
          (lowerOwner == 'owner' && (lowerUser == 'pemilik' || lowerUser == 'pemilik toko'));

      if (isOwnerMatch) {
        final savedHashedPin = await storage.getLocalPIN();
        if (hashedPin == savedHashedPin) {
          ref.read(authSessionProvider.notifier).state = const AuthUser(
            id: 'owner',
            nama: 'Pemilik Toko',
            role: 'pemilik',
          );
          if (!mounted) return;
          _goToMainMenu();
        } else {
          setState(() {
            _errorMessage = 'PIN Owner Salah!';
            _pinController.clear();
          });
        }
      } else {
        // 2. Query cashier by name and pin
        final cashierRepo = ref.read(cashierRepositoryProvider);
        final cashier = await cashierRepo.getCashierByNameAndPin(username, hashedPin);
        
        if (cashier != null) {
          ref.read(authSessionProvider.notifier).state = AuthUser(
            id: cashier.id,
            nama: cashier.nama,
            role: 'kasir',
          );
          if (!mounted) return;
          _goToMainMenu();
        } else {
          setState(() {
            _errorMessage = 'Username / PIN Salah!';
            _pinController.clear();
          });
        }
      }
    }
  }

  void _goToMainMenu() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainMenuScreen()),
    );
  }


  @override
  void dispose() {
    _pinController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.lock_person_rounded, size: 80, color: Colors.white),
                const SizedBox(height: AppSpacing.l),
                Text(
                  widget.isSetup ? "Buat PIN Keamanan Baru" : "Masukkan PIN & Username",
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge.copyWith(color: Colors.white, fontSize: 24),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.isSetup
                      ? "Digunakan untuk akses masuk harian secara luring (Offline)"
                      : "Verifikasi identitas kasir / owner untuk melanjutkan",
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: AppSpacing.xl),
                if (!widget.isSetup) ...[
                  TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.white),
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Username / Nama Karyawan',
                      labelStyle: TextStyle(color: Colors.white70),
                      hintText: 'Contoh: owner atau Nama Kasir',
                      hintStyle: TextStyle(color: Colors.white38),
                      prefixIcon: Icon(Icons.person_outline_rounded, color: Colors.white70),
                      filled: false,
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.l),
                ],
                TextField(
                  controller: _pinController,
                  autofocus: widget.isSetup,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: widget.isSetup ? TextAlign.center : TextAlign.left,
                  style: widget.isSetup
                      ? AppTypography.displayLarge.copyWith(
                          color: Colors.white,
                          letterSpacing: 20,
                        )
                      : const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: widget.isSetup ? 'Buat PIN Keamanan' : 'PIN Sesi (6 digit)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: widget.isSetup
                        ? null
                        : const Icon(Icons.lock_outline_rounded, color: Colors.white70),
                    counterText: "",
                    filled: false,
                    enabledBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: const UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.m),
                if (_errorMessage.isNotEmpty)
                  Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  text: 'Lanjutkan',
                  type: AppButtonType.secondary,
                  onPressed: _submitPin,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
