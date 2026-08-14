import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
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
  late int _status;
  String? _imagePath;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.nama ?? '');
    _status = widget.category?.status ?? 1;
    _imagePath = widget.category?.image;
  }

  @override
  void dispose() {
    _nameController.dispose();
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
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
                SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Icons.photo_library_outlined),
                  label: Text('Pilih dari Galeri'),
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Icons.camera_alt_outlined),
                  label: Text('Ambil dari Kamera'),
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
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          AppTextField(
            controller: _nameController,
            labelText: 'Nama Kategori',
            hintText: 'Masukkan nama kategori (contoh: Makanan)',
            prefixIcon: Icons.category_rounded,
            maxLines: 1,
            keyboardType: TextInputType.text,
            textInputAction: TextInputAction.done,
            validator: (v) => Validators.required(v, 'Nama Kategori'),
          ),
          SizedBox(height: 16),
          Text(
            'Gambar Kategori (Opsional)',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
          ),
          SizedBox(height: 8),
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
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Center(
                                  child: Icon(Icons.broken_image_outlined, size: 40, color: AppColors.error),
                                ),
                              )
                            : Center(
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
                          icon: Icon(Icons.delete_outline, color: Colors.white, size: 18),
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
                        Icon(Icons.add_photo_alternate_outlined, size: 40, color: AppColors.primary),
                        SizedBox(height: 8),
                        Text(
                          'Pilih Gambar (Galeri / Kamera)',
                          style: AppTypography.titleMedium.copyWith(color: AppColors.primary, fontSize: 13.sp, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Format didukung: JPG, PNG',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 10.sp),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (widget.category != null) ...[
            SizedBox(height: 16),
            Text(
              'Status Kategori',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.sp),
            ),
            SizedBox(height: 8),
            RadioGroup<int>(
              groupValue: _status,
              onChanged: (val) {
                if (val != null) setState(() => _status = val);
              },
              child: Row(
                children: [
                  Expanded(
                    child: RadioListTile<int>(
                      title: Text('Aktif', style: TextStyle(fontSize: 14.sp)),
                      value: 1,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<int>(
                      title: Text('Nonaktif', style: TextStyle(fontSize: 14.sp)),
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

  // Helper method to trigger submit from parent dialog
  bool submit() {
    if (_formKey.currentState?.validate() ?? false) {
      final input = _nameController.text.trim();
      if (input.isEmpty) return false;
      
      widget.onSubmit([input], _status, _imagePath);
      return true;
    }
    return false;
  }
}
