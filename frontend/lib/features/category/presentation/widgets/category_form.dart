import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/models/category.dart';

class CategoryForm extends StatefulWidget {
  final Category? category;
  final Function(List<String> names, int status) onSubmit;

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

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.nama ?? '');
    _status = widget.category?.status ?? 1;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
        widget.onSubmit([input], _status);
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
        widget.onSubmit(names, _status);
      }
      return true;
    }
    return false;
  }
}
