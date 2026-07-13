import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../../../product/domain/models/product.dart';

class StockInForm extends StatefulWidget {
  final List<Product> products;
  final Function({
    required String produkId,
    required int qty,
    required String tanggal,
    String? catatan,
  }) onSubmit;

  const StockInForm({
    super.key,
    required this.products,
    required this.onSubmit,
  });

  @override
  State<StockInForm> createState() => StockInFormState();
}

class StockInFormState extends State<StockInForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _qtyController;
  late TextEditingController _dateController;
  late TextEditingController _notesController;
  
  String? _selectedProductId;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController();
    _notesController = TextEditingController();
    _selectedDate = DateTime.now();
    _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(_selectedDate));

    final activeProducts = widget.products.where((p) => p.isActive).toList();
    if (activeProducts.isNotEmpty) {
      _selectedProductId = activeProducts.first.id;
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _dateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeProducts = widget.products.where((p) => p.isActive).toList();

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Product Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedProductId,
            decoration: const InputDecoration(
              labelText: 'Pilih Produk',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
            items: activeProducts.map((p) {
              final stockLabel = p.stok == -1 ? '∞' : p.stok.toString();
              return DropdownMenuItem<String>(
                value: p.id,
                child: Text('${p.nama} (Stok saat ini: $stockLabel)'),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedProductId = val);
            },
            validator: (v) => v == null ? 'Produk harus dipilih' : null,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _qtyController,
            labelText: 'Jumlah Masuk (Qty)',
            hintText: 'Masukkan jumlah produk masuk',
            prefixIcon: Icons.add_circle_outline_rounded,
            keyboardType: TextInputType.number,
            validator: (v) {
              final err = Validators.integer(v, 'Jumlah Masuk');
              if (err != null) return err;
              if (int.parse(v!) <= 0) return 'Jumlah masuk harus lebih besar dari 0';
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _dateController,
            labelText: 'Tanggal Masuk',
            hintText: 'Pilih tanggal stok masuk',
            prefixIcon: Icons.calendar_today_outlined,
            readOnly: true,
            onTap: () => _selectDate(context),
            suffixIcon: IconButton(
              icon: const Icon(Icons.date_range),
              onPressed: () => _selectDate(context),
            ),
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _notesController,
            labelText: 'Catatan',
            hintText: 'Contoh: Restock barang supplier, dll.',
            prefixIcon: Icons.notes_outlined,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  bool submit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedProductId == null) return false;
      widget.onSubmit(
        produkId: _selectedProductId!,
        qty: int.parse(_qtyController.text),
        tanggal: _dateController.text,
        catatan: _notesController.text,
      );
      return true;
    }
    return false;
  }
}
