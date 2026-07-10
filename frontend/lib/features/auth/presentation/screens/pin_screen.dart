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
        // Look up Cashiers in the database
        final cashierRepo = ref.read(cashierRepositoryProvider);
        final cashier = await cashierRepo.getCashierByPin(hashedPin);
        
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
            _errorMessage = 'PIN Salah!';
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
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
                  widget.isSetup ? "Buat PIN Keamanan Baru" : "Masukkan PIN Anda",
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge.copyWith(color: Colors.white, fontSize: 24),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.isSetup
                      ? "Digunakan untuk akses masuk harian secara luring (Offline)"
                      : "Verifikasi identitas kasir untuk melanjutkan",
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: AppTypography.displayLarge.copyWith(
                    color: Colors.white,
                    letterSpacing: 20,
                  ),
                  decoration: const InputDecoration(
                    counterText: "",
                    filled: false,
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white54),
                    ),
                    focusedBorder: UnderlineInputBorder(
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
    );
  }
}
