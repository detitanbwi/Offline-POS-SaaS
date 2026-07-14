import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/utils/currency_formatter.dart';
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

  bool _isAlwaysAvailable = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.nama ?? '');
    _priceController = TextEditingController(
      text: widget.product?.harga != null
          ? CurrencyFormatter.formatNumber(widget.product!.harga)
          : '',
    );
    _isAlwaysAvailable = widget.product?.stok == -1;
    _stockController = TextEditingController(
      text: widget.product?.stok != null
          ? (widget.product!.stok == -1 ? '' : widget.product!.stok.toString())
          : '0',
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
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
                  label: Text('Pilih dari Galeri', style: AppTypography.labelLarge.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  label: Text('Ambil dari Kamera', style: AppTypography.labelLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
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
        physics: const ClampingScrollPhysics(),
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
              initialValue: _selectedCategoryId,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Kategori Produk',
                filled: true,
                fillColor: AppColors.surface,
                labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.category_outlined, color: AppColors.textSecondary),
              ),
              items: activeCategories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat.id,
                  child: Text(
                    cat.nama,
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() => _selectedCategoryId = val);
              },
              validator: (v) => v == null ? 'Kategori harus dipilih' : null,
            ),
            const SizedBox(height: 16),
            Text(
              'Gambar Produk (Opsional)',
              style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _showImageSourcePicker(context),
              child: Container(
                height: 130,
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
                                  errorBuilder: (_, _, _) => const Center(
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
                          const Icon(Icons.add_photo_alternate_outlined, size: 36, color: AppColors.primary),
                          const SizedBox(height: 6),
                          Text(
                            'Pilih Gambar (Galeri / Kamera)',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Format didukung: JPG, PNG',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 11),
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
              hintText: 'Masukkan harga jual (contoh: 15.000)',
              prefixText: 'Rp ',
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                RupiahInputFormatter(),
              ],
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Harga Jual tidak boleh kosong';
                }
                final cleanValue = v.replaceAll('.', '');
                final numVal = num.tryParse(cleanValue);
                if (numVal == null) {
                  return 'Harga Jual harus berupa angka';
                }
                if (numVal < 0) {
                  return 'Harga Jual tidak boleh negatif';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Apakah produk selalu tersedia?',
              style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            RadioGroup<bool>(
              groupValue: _isAlwaysAvailable,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _isAlwaysAvailable = val;
                    if (val) {
                      _stockController.text = '';
                    } else {
                      _stockController.text = '0';
                    }
                  });
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text('Ya (Selalu Ada)', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
                      value: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: Text('Tidak (Pakai Stok)', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
                      value: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!_isAlwaysAvailable) ...[
              AppTextField(
                controller: _stockController,
                labelText: 'Stok Awal',
                hintText: 'Masukkan jumlah stok',
                prefixIcon: Icons.warehouse_outlined,
                keyboardType: TextInputType.number,
                readOnly: widget.product != null && widget.product!.stok != -1,
                validator: (v) {
                  if (_isAlwaysAvailable) return null;
                  return Validators.integer(v, 'Stok');
                },
              ),
              const SizedBox(height: 16),
            ],
            if (widget.product != null) ...[
              Text(
                'Status Produk',
                style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              RadioGroup<int>(
                groupValue: _status,
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<int>(
                        title: Text('Aktif', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
                        value: 1,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<int>(
                        title: Text('Nonaktif', style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
                        value: 0,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
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
      final cleanPriceText = _priceController.text.replaceAll('.', '');
      final double harga = double.tryParse(cleanPriceText) ?? 0.0;
      
      final int stockVal = _isAlwaysAvailable ? -1 : (int.tryParse(_stockController.text) ?? 0);

      widget.onSubmit(
        nama: _nameController.text.trim(),
        kategoriId: _selectedCategoryId!,
        harga: harga,
        stok: stockVal,
        status: _status,
        image: _imagePath,
      );
      return true;
    }
    return false;
  }
}

class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final double value = double.tryParse(cleanText) ?? 0;
    
    final formatter = NumberFormat.decimalPattern('id_ID');
    final String formattedText = formatter.format(value);

    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(offset: formattedText.length),
    );
  }
}
