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
import '../../domain/models/category.dart';

class CategoryForm extends StatefulWidget {
  final Category? category;
  final Function(List<String> names, int status, String? image) onSubmit;

  const CategoryForm({
    super.key,
    this.category,
    required this.onSubmit,
  });

  @override
  State<CategoryForm> createState() => CategoryFormState();
}

class CategoryFormState extends State<CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _imageUrlController;
  late int _status;
  String? _imagePath;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.nama ?? '');
    _status = widget.category?.status ?? 1;
    _imagePath = widget.category?.image;
    _imageUrlController = TextEditingController(
      text: _imagePath != null && _imagePath!.startsWith('http') ? _imagePath : '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
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
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _nameController,
            labelText: 'Nama Kategori',
            hintText: widget.category == null
                ? 'Masukkan nama kategori (bisa dipisah koma/baris baru)'
                : 'Masukkan nama kategori (contoh: Makanan)',
            prefixIcon: Icons.category_rounded,
            maxLines: widget.category == null ? null : 1,
            keyboardType: widget.category == null ? TextInputType.multiline : TextInputType.text,
            validator: (v) => Validators.required(v, 'Nama Kategori'),
          ),
          if (widget.category == null) ...[
            const SizedBox(height: 6),
            Text(
              'Gunakan tanda koma (,) atau baris baru untuk memasukkan beberapa kategori sekaligus.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Gambar Kategori (Opsional)',
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
          if (widget.category != null) ...[
            const SizedBox(height: 16),
            const Text(
              'Status Kategori',
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
    );
  }

  // Helper method to trigger submit from parent dialog
  bool submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final input = _nameController.text.trim();
      if (widget.category != null) {
        // Edit mode: treat whole input as single category name
        widget.onSubmit([input], _status, _imagePath);
      } else {
        // Add mode: split by commas and newlines
        final names = input
            .split(RegExp(r'[,\n]'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        
        if (names.isEmpty) {
          return false;
        }
        widget.onSubmit(names, _status, _imagePath);
      }
      return true;
    }
    return false;
  }
}
