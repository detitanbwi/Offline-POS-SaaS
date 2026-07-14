import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/di/providers.dart';

class StoreProfileScreen extends ConsumerStatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  ConsumerState<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends ConsumerState<StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ownerUsernameController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadStoreInfo();
  }

  Future<void> _loadStoreInfo() async {
    final storage = ref.read(secureStorageServiceProvider);
    final name = await storage.getStoreName() ?? '';
    final address = await storage.getStoreAddress() ?? '';
    final phone = await storage.getStorePhone() ?? '';
    final ownerUsername = await storage.getOwnerUsername() ?? 'owner';

    if (mounted) {
      setState(() {
        _nameController.text = name;
        _addressController.text = address;
        _phoneController.text = phone;
        _ownerUsernameController.text = ownerUsername;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);

    final storage = ref.read(secureStorageServiceProvider);
    await storage.saveStoreInfo(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    await storage.saveOwnerUsername(_ownerUsernameController.text.trim());

    setState(() => _isSaving = false);

    if (mounted) {
      AppSnackbar.showSuccess(context, 'Profil toko berhasil diperbarui!');
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _ownerUsernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Profil & Informasi Toko'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.store_rounded,
                                    color: AppColors.primary,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pengaturan Toko',
                                        style: AppTypography.titleLarge,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Data ini akan ditampilkan pada kepala struk belanja cetak dan pratinjau.',
                                        style: AppTypography.bodyMedium.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            AppTextField(
                              controller: _nameController,
                              labelText: 'Nama Toko / Usaha',
                              hintText: 'Contoh: Kopi Maju Bersama',
                              prefixIcon: Icons.storefront_outlined,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Nama Toko wajib diisi!';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.l),
                            AppTextField(
                              controller: _addressController,
                              labelText: 'Alamat Lengkap Toko',
                              hintText: 'Contoh: Jl. Merdeka No. 45, Jakarta Pusat',
                              prefixIcon: Icons.location_on_outlined,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Alamat Toko wajib diisi!';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.l),
                            AppTextField(
                              controller: _phoneController,
                              labelText: 'Nomor Telepon Toko',
                              hintText: 'Contoh: 081234567890',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Nomor Telepon wajib diisi!';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.l),
                            AppTextField(
                              controller: _ownerUsernameController,
                              labelText: 'Username Owner / Pemilik (untuk Login)',
                              hintText: 'Contoh: owner atau username baru',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Username Owner wajib diisi!';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.xl),
                            AppButton(
                              text: 'Simpan Perubahan',
                              isLoading: _isSaving,
                              icon: Icons.save_rounded,
                              onPressed: _handleSave,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
