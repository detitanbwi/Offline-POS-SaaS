import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/utils/image_compression_util.dart';
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
  final _ownerNameController = TextEditingController();
  final _ownerUsernameController = TextEditingController();
  final _imagePicker = ImagePicker();
  String? _logoPath;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isProcessingLogo = false;

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
    final ownerName = await storage.getOwnerName() ?? 'Pemilik Toko';
    final logoPath = await storage.getStoreLogo();

    if (mounted) {
      setState(() {
        _nameController.text = name;
        _addressController.text = address;
        _phoneController.text = phone;
        _ownerNameController.text = ownerName;
        _ownerUsernameController.text = ownerUsername;
        _logoPath = (logoPath != null && File(logoPath).existsSync()) ? logoPath : null;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndProcessLogo(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (picked != null) {
        setState(() => _isProcessingLogo = true);
        final processedPath = await ImageCompressionUtil.processStoreLogo(picked.path);
        if (processedPath != null) {
          final storage = ref.read(secureStorageServiceProvider);
          await storage.saveStoreLogo(processedPath);
          if (mounted) {
            setState(() {
              _logoPath = processedPath;
              _isProcessingLogo = false;
            });
            AppSnackbar.showSuccess(context, 'Logo toko berhasil dipasang & dikompresi 1:1');
          }
        } else {
          if (mounted) {
            setState(() => _isProcessingLogo = false);
            AppSnackbar.showError(context, 'Gagal memproses gambar logo toko');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingLogo = false);
        AppSnackbar.showError(context, 'Terjadi kesalahan saat memilih logo: $e');
      }
    }
  }

  void _showLogoPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih Sumber Logo Usaha',
                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4.h),
              Text(
                'Gambar akan otomatis dipotong rasio 1:1 untuk kepala struk cetak.',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
              ),
              SizedBox(height: 16.h),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: const Text('Buka Galeri Foto'),
                subtitle: const Text('Pilih file gambar logo dari penyimpanan HP'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndProcessLogo(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: const Text('Ambil Foto Kamera'),
                subtitle: const Text('Foto logo langsung menggunakan kamera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndProcessLogo(ImageSource.camera);
                },
              ),
              if (_logoPath != null) ...[
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                  ),
                  title: const Text('Hapus Logo Toko', style: TextStyle(color: AppColors.error)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final storage = ref.read(secureStorageServiceProvider);
                    await storage.deleteStoreLogo();
                    if (mounted) {
                      setState(() => _logoPath = null);
                      AppSnackbar.showInfo(context, 'Logo toko berhasil dihapus.');
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSaving = true);
    await Future.delayed(const Duration(milliseconds: 100));

    final storage = ref.read(secureStorageServiceProvider);
    await storage.saveStoreInfo(
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      phone: _phoneController.text.trim(),
    );
    await storage.saveOwnerName(_ownerNameController.text.trim());
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
    _ownerNameController.dispose();
    _ownerUsernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Profil & Informasi Toko'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 560.w),
                    child: AppCard(
                      padding: EdgeInsets.all(20.r),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10.r),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryContainer,
                                    borderRadius: BorderRadius.circular(12.r),
                                  ),
                                  child: Icon(
                                    Icons.store_rounded,
                                    color: AppColors.primary,
                                    size: 26.r,
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pengaturan Toko',
                                        style: AppTypography.titleLarge,
                                      ),
                                      SizedBox(height: 2.h),
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
                            SizedBox(height: 20.h),

                            // Logo Upload Section
                            Container(
                              padding: EdgeInsets.all(16.r),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14.r),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: _isProcessingLogo ? null : _showLogoPickerSheet,
                                    child: Container(
                                      width: 72.r,
                                      height: 72.r,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12.r),
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
                                        image: _logoPath != null
                                            ? DecorationImage(
                                                image: FileImage(File(_logoPath!)),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: _isProcessingLogo
                                          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                                          : _logoPath == null
                                              ? Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 28.r),
                                                    SizedBox(height: 2.h),
                                                    Text('1:1', style: TextStyle(fontSize: 10.sp, color: AppColors.primary, fontWeight: FontWeight.bold)),
                                                  ],
                                                )
                                              : null,
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Logo Usaha / Struk',
                                          style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          _logoPath != null
                                              ? 'Logo aktif terpasang untuk kepala struk cetak dan nota bill.'
                                              : 'Tambahkan logo toko untuk dicetak di kepala nota belanja (rasio 1:1).',
                                          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                        ),
                                        SizedBox(height: 8.h),
                                        Row(
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: _isProcessingLogo ? null : _showLogoPickerSheet,
                                              icon: Icon(_logoPath == null ? Icons.upload_rounded : Icons.edit_rounded, size: 14.r),
                                              label: Text(_logoPath == null ? 'Unggah Logo' : 'Ganti Logo', style: TextStyle(fontSize: 12.sp)),
                                              style: OutlinedButton.styleFrom(
                                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            SizedBox(height: 18.h),
                            AppTextField(
                              controller: _nameController,
                              labelText: 'Nama Toko / Usaha',
                              hintText: 'Contoh: Kopi Maju Bersama',
                              prefixIcon: Icons.storefront_outlined,
                              maxLength: 100,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Nama Toko wajib diisi!';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 18.h),
                            AppTextField(
                              controller: _addressController,
                              labelText: 'Alamat Lengkap Toko',
                              hintText: 'Contoh: Jl. Merdeka No. 45, Jakarta Pusat',
                              prefixIcon: Icons.location_on_outlined,
                              maxLines: 3,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Alamat Toko wajib diisi!';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 18.h),
                            AppTextField(
                              controller: _phoneController,
                              labelText: 'Nomor Telepon Toko',
                              hintText: 'Contoh: 081234567890',
                              prefixIcon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                              maxLength: 20,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Nomor Telepon wajib diisi!';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 18.h),
                            AppTextField(
                              controller: _ownerNameController,
                              labelText: 'Nama Lengkap Owner / Pemilik (untuk Tampilan)',
                              hintText: 'Contoh: Pemilik Toko / Nama Anda',
                              prefixIcon: Icons.badge_outlined,
                              maxLength: 50,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Nama Owner wajib diisi!';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 18.h),
                            AppTextField(
                              controller: _ownerUsernameController,
                              labelText: 'Username Owner / Pemilik (untuk Login)',
                              hintText: 'Contoh: owner atau username baru',
                              prefixIcon: Icons.person_outline_rounded,
                              maxLength: 50,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Username Owner wajib diisi!';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 20.h),
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
