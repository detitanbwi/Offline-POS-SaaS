import 'package:flutter/material.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
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
  }) onSubmit;

  const ProductForm({
    super.key,
    this.product,
    required this.categories,
    required this.onSubmit,
  });

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  String? _selectedCategoryId;
  late int _status;

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

  @override
  Widget build(BuildContext context) {
    final activeCategories = widget.categories.where((c) => c.isActive || c.id == widget.product?.kategoriId).toList();

    return Form(
      key: _formKey,
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
      );
      return true;
    }
    return false;
  }
}
