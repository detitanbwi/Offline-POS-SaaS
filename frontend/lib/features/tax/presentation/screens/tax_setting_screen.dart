import 'package:flutter/material.dart';
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
  late TextEditingController _percentageController;
  bool _taxEnabled = false;

  @override
  void initState() {
    super.initState();
    _percentageController = TextEditingController();
    
    // Defer initialization to after build to load notifier values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(taxNotifierProvider);
      if (state.taxSetting != null) {
        setState(() {
          _taxEnabled = state.taxSetting!.isEnabled;
          _percentageController.text = state.taxSetting!.percentage.toStringAsFixed(1);
        });
      }
    });
  }

  @override
  void dispose() {
    _percentageController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState?.validate() ?? false) {
      final percentage = double.parse(_percentageController.text);
      final ok = await ref.read(taxNotifierProvider.notifier).updateTaxSetting(_taxEnabled, percentage);
      
      if (!mounted) return;
      if (ok) {
        AppSnackbar.showSuccess(context, 'Pengaturan pajak berhasil diperbarui!');
      } else {
        final err = ref.read(taxNotifierProvider).errorMessage;
        if (err != null) AppSnackbar.showError(context, err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taxNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Pengaturan Pajak (PPN)'),
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
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.l),
                        borderSide: const BorderSide(color: AppColors.divider),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Aktifkan Pajak (PPN)',
                                        style: AppTypography.titleMedium.copyWith(fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Jika diaktifkan, setiap transaksi kasir akan dikenakan pajak tambahan.',
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _taxEnabled,
                                  activeThumbColor: AppColors.primary,
                                  onChanged: (val) {
                                    setState(() => _taxEnabled = val);
                                  },
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            AppTextField(
                              controller: _percentageController,
                              labelText: 'Persentase Pajak (%)',
                              hintText: 'Contoh: 11',
                              prefixIcon: Icons.percent_rounded,
                              keyboardType: TextInputType.number,
                              validator: (v) {
                                final err = Validators.number(v, 'Persentase Pajak');
                                if (err != null) return err;
                                final val = double.parse(v!);
                                if (val < 0 || val > 100) return 'Persentase harus berada di antara 0% - 100%';
                                return null;
                              },
                            ),
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
