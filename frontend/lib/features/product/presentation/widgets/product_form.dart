import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../domain/models/product.dart';
import '../../../category/domain/models/category.dart';

class ProductForm extends StatefulWidget {
  final Product? product;
  final List<Category> categories;
  final Function({
    required String nama,
    required String kategoriId,
    required double harga,
    required int stok,
    required int status,
    String? image,
  }) onSubmit;

  const ProductForm({
    super.key,
    this.product,
    required this.categories,
    required this.onSubmit,
  });

  @override
  State<ProductForm> createState() => ProductFormState();
}

class ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  String? _selectedCategoryId;
  late int _status;
  String? _imagePath;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.nama ?? '');
    _priceController = TextEditingController(
      text: widget.product?.harga != null ? widget.product!.harga.toStringAsFixed(0) : '',
    );
    _stockController = TextEditingController(
      text: widget.product?.stok != null ? widget.product!.stok.toString() : '0',
    );
    _imagePath = widget.product?.image;
    
    // Set default category
    final activeCategories = widget.categories.where((c) => c.isActive).toList();
    if (widget.product != null) {
      _selectedCategoryId = widget.product!.kategoriId;
    } else if (activeCategories.isNotEmpty) {
      _selectedCategoryId = activeCategories.first.id;
    }
    
    _status = widget.product?.status ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        final savedPath = await _saveLocalImage(picked.path);
        if (savedPath != null) {
          setState(() {
            _imagePath = savedPath;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  void _showImageSourcePicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pilih Sumber Gambar',
              style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Pilih dari Galeri'),
              onPressed: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Ambil dari Kamera'),
              onPressed: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }


  Future<String?> _saveLocalImage(String pickedFilePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(appDir.path, 'pos_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${p.basename(pickedFilePath)}';
      final destPath = p.join(imagesDir.path, fileName);
      await File(pickedFilePath).copy(destPath);
      return destPath;
    } catch (e) {
      debugPrint('Error saving local image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCategories = widget.categories.where((c) => c.isActive || c.id == widget.product?.kategoriId).toList();

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _nameController,
              labelText: 'Nama Produk',
              hintText: 'Masukkan nama produk (contoh: Nasi Goreng)',
              prefixIcon: Icons.shopping_bag_outlined,
              validator: (v) => Validators.required(v, 'Nama Produk'),
            ),
            const SizedBox(height: 16),
            // Category Dropdown
            DropdownButtonFormField<String>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: activeCategories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat.id,
                  child: Text(cat.nama),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedCategoryId = val);
              },
              validator: (v) => v == null ? 'Kategori harus dipilih' : null,
            ),
            const SizedBox(height: 16),
            const Text(
              'Gambar Produk (Opsional)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showImageSourcePicker(context),
              child: Container(
                height: 140,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider, width: 1.5),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_imagePath != null && _imagePath!.isNotEmpty) ...[
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Validators.isValidLocalFile(_imagePath!)
                              ? Image.file(
                                  File(_imagePath!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.broken_image_outlined, size: 40, color: AppColors.error),
                                  ),
                                )
                              : const Center(
                                  child: Icon(Icons.image_outlined, size: 40, color: AppColors.disabled),
                                ),
                        ),
                      ),

                      Positioned(
                        top: 8,
                        right: 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.black54,
                          radius: 18,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white, size: 18),
                            onPressed: () {
                              setState(() {
                                _imagePath = null;
                              });
                            },
                          ),
                        ),
                      ),
                    ] else ...[
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.primary),
                          const SizedBox(height: 8),
                          Text(
                            'Pilih Gambar (Galeri / Kamera)',
                            style: AppTypography.titleMedium.copyWith(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Format didukung: JPG, PNG',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _priceController,
              labelText: 'Harga Jual (Rupiah)',
              hintText: 'Masukkan harga jual (contoh: 15000)',
              prefixIcon: Icons.attach_money_rounded,
              keyboardType: TextInputType.number,
              validator: (v) => Validators.number(v, 'Harga Jual'),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _stockController,
              labelText: 'Stok Awal',
              hintText: 'Masukkan jumlah stok',
              prefixIcon: Icons.warehouse_outlined,
              keyboardType: TextInputType.number,
              readOnly: widget.product != null, // Read-only on edit!
              validator: (v) => Validators.integer(v, 'Stok'),
            ),
            if (widget.product != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Status Produk',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<int>(
                      title: const Text('Aktif', style: TextStyle(fontSize: 14)),
                      value: 1,
                      groupValue: _status,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<int>(
                      title: const Text('Nonaktif', style: TextStyle(fontSize: 14)),
                      value: 0,
                      groupValue: _status,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool submit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedCategoryId == null) return false;
      widget.onSubmit(
        nama: _nameController.text.trim(),
        kategoriId: _selectedCategoryId!,
        harga: double.parse(_priceController.text),
        stok: int.parse(_stockController.text),
        status: _status,
        image: _imagePath,
      );
      return true;
    }
    return false;
  }
}
