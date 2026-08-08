import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:crypto/crypto.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/di/providers.dart';
import '../../../menu/presentation/screens/main_menu_screen.dart';
import '../../domain/models/auth_user.dart';
import '../providers/auth_providers.dart';
import '../../../security/presentation/providers/security_providers.dart';
import '../widgets/forgot_pin_email_modal.dart';

class AccountItem {
  final String id;
  final String nama;
  final String username;
  final String role;
  final bool isOwner;

  const AccountItem({
    required this.id,
    required this.nama,
    required this.username,
    required this.role,
    required this.isOwner,
  });
}

class PinScreen extends ConsumerStatefulWidget {
  final bool isSetup;
  const PinScreen({super.key, required this.isSetup});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  final _pinController = TextEditingController();
  String _errorMessage = '';

  List<AccountItem> _accounts = [];
  bool _isLoadingAccounts = true;
  AccountItem? _selectedAccount;

  @override
  void initState() {
    super.initState();
    if (!widget.isSetup) {
      _loadAccounts();
    }
  }

  Future<void> _loadAccounts() async {
    setState(() => _isLoadingAccounts = true);
    try {
      final storage = ref.read(secureStorageServiceProvider);
      final ownerUsername = await storage.getOwnerUsername() ?? 'owner';
      final ownerName = await storage.getOwnerName() ?? 'Pemilik Toko';

      final cashierRepo = ref.read(cashierRepositoryProvider);
      final cashiers = await cashierRepo.getAllCashiers();
      final activeCashiers =
          cashiers.where((c) => c.isActive && !c.isSoftDeleted).toList();

      final items = <AccountItem>[
        AccountItem(
          id: 'owner',
          nama: ownerName,
          username: ownerUsername,
          role: 'pemilik',
          isOwner: true,
        ),
        ...activeCashiers.map((c) => AccountItem(
              id: c.id,
              nama: c.nama,
              username: c.username,
              role: 'kasir',
              isOwner: false,
            )),
      ];

      if (mounted) {
        setState(() {
          _accounts = items;
          _isLoadingAccounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAccounts = false);
      }
    }
  }

  String _hashPIN(String pin) {
    const salt = 'OfflinePOSSecureSalt_Sprint4_2026';
    var bytes = utf8.encode(pin + salt);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _isSubmitting = false;

  Future<void> _submitPin() async {
    final pin = _pinController.text.trim();
    final hashedPin = _hashPIN(pin);

    if (widget.isSetup) {
      if (pin.length != 6) {
        final msg = 'PIN Keamanan harus 6 digit!';
        setState(() => _errorMessage = msg);
        AppSnackbar.showError(context, msg);
        return;
      }
      if (!mounted) return;

      setState(() => _isSubmitting = true);
      try {
        final storage = ref.read(secureStorageServiceProvider);
        final licenseKey = await storage.getLicenseKey() ?? 'XXXX-XXXX-XXXX';
        final service = ref.read(securityServiceProvider);
        
        await service.initializeMasterSecurity(
          masterPin: pin,
          licenseKey: licenseKey,
        );

        if (!mounted) return;
        ref.read(authSessionProvider.notifier).state = const AuthUser(
          id: 'owner',
          nama: 'Pemilik Toko',
          role: 'pemilik',
        );
        AppSnackbar.showSuccess(context, 'PIN Keamanan berhasil dibuat!');
        _goToMainMenu();
      } catch (e) {
        if (!mounted) return;
        AppSnackbar.showError(context, 'Gagal membuat PIN: $e');
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
      return;
    }

    if (_selectedAccount == null) {
      setState(() => _errorMessage = 'Silakan pilih akun pengguna terlebih dahulu!');
      return;
    }

    if (pin.length != 6) {
      setState(() => _errorMessage = 'PIN harus 6 digit angka!');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_selectedAccount!.isOwner) {
        final securityRepo = ref.read(securityRepositoryProvider);
        final isPinValid = await securityRepo.validateMasterPin(pin);
        if (isPinValid) {
          ref.read(authSessionProvider.notifier).state = AuthUser(
            id: 'owner',
            nama: _selectedAccount!.nama,
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
        final cashierRepo = ref.read(cashierRepositoryProvider);
        final cashier = await cashierRepo.getCashierByNameAndPin(
            _selectedAccount!.username, hashedPin);

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
            _errorMessage = 'PIN Kasir Salah!';
            _pinController.clear();
          });
        }
      }
    } catch (e) {
      debugPrint('Error submit PIN: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Gagal verifikasi: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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

  Widget _buildSetupView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_person_rounded, size: 64, color: Colors.white),
        const SizedBox(height: 16),
        Text(
          "Buat PIN Keamanan (6 Digit)",
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(color: Colors.white),
        ),
        SizedBox(height: 4.h),
        Text(
          "Masukkan 6 digit angka untuk akses masuk harian secara luring (Offline)",
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
        ),
        SizedBox(height: 24.h),
        TextField(
          controller: _pinController,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: AppTypography.displayLarge.copyWith(
            color: Colors.white,
            letterSpacing: 16.w,
          ),
          decoration: const InputDecoration(
            labelText: 'Buat 6 Digit PIN Keamanan',
            labelStyle: TextStyle(color: Colors.white70),
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
        SizedBox(height: 12.h),
        if (_errorMessage.isNotEmpty)
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.secondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        SizedBox(height: 24.h),
        AppButton(
          text: 'Simpan PIN Keamanan',
          type: AppButtonType.secondary,
          onPressed: _submitPin,
        ),
      ],
    );
  }

  Widget _buildAccountListView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_person_rounded, size: 64, color: Colors.white),
        const SizedBox(height: 16),
        Text(
          "Pilih Akun Masuk",
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(color: Colors.white),
        ),
        SizedBox(height: 4.h),
        Text(
          "Pilih akun pengguna Anda untuk masuk ke sesi Offline POS",
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
        ),
        SizedBox(height: 24.h),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _isLoadingAccounts
              ? const Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        "PENGGUNA TERSEDIA",
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _accounts.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, indent: 68),
                      itemBuilder: (context, index) {
                        final account = _accounts[index];
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedAccount = account;
                              _errorMessage = '';
                              _pinController.clear();
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: account.isOwner
                                      ? Colors.amber.shade100
                                      : AppColors.primaryContainer,
                                  child: Icon(
                                    account.isOwner
                                        ? Icons.admin_panel_settings_rounded
                                        : Icons.person_rounded,
                                    color: account.isOwner
                                        ? Colors.amber.shade800
                                        : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        account.nama,
                                        style:
                                            AppTypography.titleMedium.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: account.isOwner
                                                ? Colors.amber.shade50
                                                : Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            account.isOwner
                                                ? 'PEMILIK TOKO'
                                                : 'KASIR',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: account.isOwner
                                                  ? Colors.amber.shade800
                                                  : Colors.blue.shade800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildPinEntryView() {
    final account = _selectedAccount!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: account.isOwner
                    ? Colors.amber.shade700
                    : Colors.blue.shade700,
                child: Icon(
                  account.isOwner
                      ? Icons.admin_panel_settings_rounded
                      : Icons.person_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.nama,
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.isOwner ? 'Akun Pemilik Toko' : 'Akun Kasir',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                label: const Text('Ganti Akun'),
                onPressed: () {
                  setState(() {
                    _selectedAccount = null;
                    _errorMessage = '';
                    _pinController.clear();
                  });
                },
              ),
            ],
          ),
        ),
        SizedBox(height: 28.h),
        Text(
          "Masukkan PIN Akses",
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(color: Colors.white),
        ),
        SizedBox(height: 4.h),
        Text(
          "Verifikasi 6 digit PIN akun Anda",
          textAlign: TextAlign.center,
          style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
        ),
        SizedBox(height: 24.h),
        TextField(
          controller: _pinController,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitPin(),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'PIN Sesi (6 digit)',
            labelStyle: TextStyle(color: Colors.white70),
            prefixIcon:
                Icon(Icons.lock_outline_rounded, color: Colors.white70),
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
        SizedBox(height: 12.h),
        if (_errorMessage.isNotEmpty) ...[
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: Colors.red.shade800,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 24.h),
        AppButton(
          text: 'Masuk ke Sistem',
          type: AppButtonType.secondary,
          isLoading: _isSubmitting,
          onPressed: _submitPin,
        ),
        if (_selectedAccount!.isOwner) ...[
          SizedBox(height: 14.h),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.email_outlined, size: 18),
            label: const Text('Lupa PIN? (OTP via Email)'),
            onPressed: () {
              ForgotPinEmailModal.show(context);
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: widget.isSetup
                  ? _buildSetupView()
                  : _selectedAccount != null
                      ? _buildPinEntryView()
                      : _buildAccountListView(),
            ),
          ),
        ),
      ),
    );
  }
}

