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
  late TextEditingController _imageUrlController;
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
    _imageUrlController = TextEditingController(
      text: _imagePath != null && _imagePath!.startsWith('http') ? _imagePath : '',
    );
    
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
    _imageUrlController.dispose();
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
            _imageUrlController.clear();
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Preview
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _imagePath == null || _imagePath!.isEmpty
                        ? Icon(Icons.add_photo_alternate_outlined, color: Colors.grey[400], size: 36)
                        : _imagePath!.startsWith('http')
                            ? Image.network(
                                _imagePath!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: Colors.red[300], size: 36),
                              )
                            : Image.file(
                                File(_imagePath!),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined, color: Colors.red[300], size: 36),
                              ),
                  ),
                ),
                const SizedBox(width: 16),
                // Buttons to Pick
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined, size: 16),
                            label: const Text('Galeri', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _pickImage(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined, size: 16),
                            label: const Text('Kamera', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                            ),
                          ),
                          if (_imagePath != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  _imagePath = null;
                                  _imageUrlController.clear();
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _imageUrlController,
                        labelText: 'Atau URL Gambar Web',
                        hintText: 'https://example.com/image.jpg',
                        prefixIcon: Icons.link_rounded,
                        onChanged: (val) {
                          setState(() {
                            _imagePath = val.trim().isEmpty ? null : val.trim();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
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
