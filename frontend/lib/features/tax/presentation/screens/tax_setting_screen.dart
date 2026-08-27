import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../../application/tax_notifier.dart';

class TaxSettingScreen extends ConsumerStatefulWidget {
  const TaxSettingScreen({super.key});

  @override
  ConsumerState<TaxSettingScreen> createState() => _TaxSettingScreenState();
}

class _TaxSettingScreenState extends ConsumerState<TaxSettingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _taxPercentageController;
  late TextEditingController _servicePercentageController;
  bool _taxEnabled = false;
  bool _serviceEnabled = false;
  bool _serviceAfterTax = false;
  bool _serviceExcludeOnline = true;

  @override
  void initState() {
    super.initState();
    _taxPercentageController = TextEditingController();
    _servicePercentageController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(taxNotifierProvider.notifier).loadTaxSetting();
      if (!mounted) return;
      final setting = ref.read(taxNotifierProvider).taxSetting;
      if (setting != null) {
        setState(() {
          _taxEnabled = setting.isEnabled;
          final tp = setting.percentage;
          _taxPercentageController.text = tp % 1 == 0 ? tp.toInt().toString() : tp.toString();

          _serviceEnabled = setting.isServiceChargeEnabled;
          final sp = setting.serviceChargePercentage;
          _servicePercentageController.text = sp % 1 == 0 ? sp.toInt().toString() : sp.toString();

          _serviceAfterTax = setting.isServiceChargeAfterTax;
          _serviceExcludeOnline = setting.isServiceChargeExcludeOnline;
        });
      }
    });
  }

  @override
  void dispose() {
    _taxPercentageController.dispose();
    _servicePercentageController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      final taxPercentage = double.tryParse(_taxPercentageController.text) ?? 0.0;
      final servicePercentage = double.tryParse(_servicePercentageController.text) ?? 0.0;

      final ok = await ref.read(taxNotifierProvider.notifier).updateTaxAndServiceSetting(
            taxEnable: _taxEnabled,
            taxPercentage: taxPercentage,
            serviceEnable: _serviceEnabled,
            servicePercentage: servicePercentage,
            serviceAfterTax: _serviceAfterTax,
            serviceExcludeOnline: _serviceExcludeOnline,
          );

      if (!mounted) return;
      if (ok) {
        AppSnackbar.showSuccess(context, 'Pengaturan Pajak & Service Charge berhasil disimpan!');
      } else {
        final err = ref.read(taxNotifierProvider).errorMessage;
        if (err != null) AppSnackbar.showError(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TaxState>(taxNotifierProvider, (previous, next) {
      if (next.taxSetting != null &&
          (previous?.taxSetting != next.taxSetting || _taxPercentageController.text.isEmpty)) {
        setState(() {
          _taxEnabled = next.taxSetting!.isEnabled;
          final tp = next.taxSetting!.percentage;
          _taxPercentageController.text = tp % 1 == 0 ? tp.toInt().toString() : tp.toString();

          _serviceEnabled = next.taxSetting!.isServiceChargeEnabled;
          final sp = next.taxSetting!.serviceChargePercentage;
          _servicePercentageController.text = sp % 1 == 0 ? sp.toInt().toString() : sp.toString();

          _serviceAfterTax = next.taxSetting!.isServiceChargeAfterTax;
          _serviceExcludeOnline = next.taxSetting!.isServiceChargeExcludeOnline;
        });
      }
    });

    final state = ref.watch(taxNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Pajak & Service Charge'),
      ),
      body: SafeArea(
        child: state.isLoading && state.taxSetting == null
            ? const AppLoading(message: 'Memuat data...')
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. CARD PAJAK (PPN)
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        borderSide: const BorderSide(color: AppColors.divider),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20.sp),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Pajak Tambahan (PPN)',
                                              style: AppTypography.titleMedium.copyWith(fontSize: 16.sp, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Jika diaktifkan, setiap transaksi kasir akan dikenakan pajak pertambahan nilai.',
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: _taxEnabled,
                                  activeThumbColor: AppColors.primary,
                                  onChanged: (val) {
                                    setState(() => _taxEnabled = val);
                                  },
                                ),
                              ],
                            ),
                            if (_taxEnabled) ...[
                              const Divider(height: 28),
                              AppTextField(
                                controller: _taxPercentageController,
                                labelText: 'Persentase Pajak (%)',
                                hintText: 'Contoh: 11',
                                prefixIcon: Icons.percent_rounded,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                maxLength: 7,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
                                ],
                                validator: (v) {
                                  if (!_taxEnabled) return null;
                                  final err = Validators.number(v, 'Persentase Pajak');
                                  if (err != null) return err;
                                  final val = double.tryParse(v!);
                                  if (val == null) return 'Persentase Pajak tidak valid';
                                  if (val < 0 || val > 100) return 'Persentase harus berada di antara 0% - 100%';
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. CARD SERVICE CHARGE
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        borderSide: const BorderSide(color: AppColors.divider),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.room_service_outlined, color: AppColors.primary, size: 20.sp),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Service Charge (Biaya Layanan)',
                                              style: AppTypography.titleMedium.copyWith(fontSize: 16.sp, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Biaya layanan yang dikenakan kepada pelanggan pada setiap pesanan/meja.',
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Switch(
                                  value: _serviceEnabled,
                                  activeThumbColor: AppColors.primary,
                                  onChanged: (val) {
                                    setState(() => _serviceEnabled = val);
                                  },
                                ),
                              ],
                            ),
                            if (_serviceEnabled) ...[
                              const Divider(height: 28),
                              AppTextField(
                                controller: _servicePercentageController,
                                labelText: 'Persentase Service Charge (%)',
                                hintText: 'Contoh: 5',
                                prefixIcon: Icons.percent_rounded,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                maxLength: 7,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,4}')),
                                ],
                                validator: (v) {
                                  if (!_serviceEnabled) return null;
                                  final err = Validators.number(v, 'Persentase Service Charge');
                                  if (err != null) return err;
                                  final val = double.tryParse(v!);
                                  if (val == null) return 'Persentase tidak valid';
                                  if (val < 0 || val > 100) return 'Persentase harus berada di antara 0% - 100%';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Hitung Setelah Pajak (Compound Mode)',
                                            style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Switch(
                                          value: _serviceAfterTax,
                                          activeThumbColor: AppColors.primary,
                                          onChanged: (val) {
                                            setState(() => _serviceAfterTax = val);
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _serviceAfterTax
                                          ? 'Mode Aktif: Pajak dihitung dari Subtotal, kemudian Service Charge dihitung dari total Subtotal + Pajak.'
                                          : 'Mode Standar: Service Charge dihitung dari Subtotal, kemudian Pajak dihitung dari total Subtotal + Service Charge.',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.divider),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Kecualikan untuk Take Away & Online Food',
                                            style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Switch(
                                          value: _serviceExcludeOnline,
                                          activeThumbColor: AppColors.primary,
                                          onChanged: (val) {
                                            setState(() => _serviceExcludeOnline = val);
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Jika aktif, pesanan Take Away dan pesanan Online Food (GrabFood/GoFood/ShopeeFood) tidak akan dikenakan biaya layanan (Service Charge 0%).',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 11.sp,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        text: 'Simpan Pengaturan',
                        isLoading: state.isLoading,
                        onPressed: _handleSave,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
