import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../../domain/models/category.dart';

class CategoryForm extends StatefulWidget {
  final Category? category;
  final Function(String name, int status) onSubmit;

  const CategoryForm({
    super.key,
    this.category,
    required this.onSubmit,
  });

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
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
            hintText: 'Masukkan nama kategori (contoh: Makanan)',
            prefixIcon: Icons.category_rounded,
            validator: (v) => Validators.required(v, 'Nama Kategori'),
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
      widget.onSubmit(_nameController.text.trim(), _status);
      return true;
    }
    return false;
  }
}
