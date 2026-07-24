import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../../../product/domain/models/product.dart';

class StockInForm extends StatefulWidget {
  final List<Product> products;
  final Function({
    required String produkId,
    required String type,
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
  
  String _selectedType = 'in'; // 'in' or 'out'
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Jenis Mutasi Stok Toggle / Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedType,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Jenis Mutasi Stok',
                filled: true,
                fillColor: AppColors.surface,
                labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                prefixIcon: Icon(
                  _selectedType == 'in' ? Icons.add_circle_outline : Icons.remove_circle_outline,
                  color: _selectedType == 'in' ? AppColors.success : AppColors.error,
                ),
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: 'in',
                  child: Text('Stok Masuk (Penambahan +)'),
                ),
                DropdownMenuItem<String>(
                  value: 'out',
                  child: Text('Stok Keluar / Minus (Pengurangan -)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedType = val);
                }
              },
            ),
            const SizedBox(height: 16),
            // Product Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedProductId,
              isExpanded: true,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Pilih Produk',
                filled: true,
                fillColor: AppColors.surface,
                labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary),
              ),
              items: activeProducts.map((p) {
                final stockLabel = p.stok == -1 ? '∞' : p.stok.toString();
                return DropdownMenuItem<String>(
                  value: p.id,
                  child: Text(
                    '${p.nama} (Stok saat ini: $stockLabel)',
                    style: AppTypography.bodyLarge.copyWith(color: AppColors.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
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
              labelText: _selectedType == 'in' ? 'Jumlah Masuk (Qty)' : 'Jumlah Keluar / Minus (Qty)',
              hintText: _selectedType == 'in' ? 'Masukkan jumlah produk masuk' : 'Masukkan jumlah produk berkurang',
              prefixIcon: _selectedType == 'in' ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
              keyboardType: TextInputType.number,
              maxLength: 5,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final err = Validators.integer(v, 'Jumlah Qty');
                if (err != null) return err;
                final val = int.tryParse(v!);
                if (val == null || val <= 0) return 'Jumlah Qty harus lebih besar dari 0';
                if (val > 99999) return 'Jumlah Qty maksimal 99.999';
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _dateController,
              labelText: 'Tanggal Transaksi Stok',
              hintText: 'Pilih tanggal stok',
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
              labelText: _selectedType == 'out' ? 'Catatan Pengurangan (Wajib)' : 'Catatan (Opsional)',
              hintText: _selectedType == 'out'
                  ? 'Contoh: Barang rusak, kadaluarsa, hilang, atau selisih stok.'
                  : 'Contoh: Restock barang dari supplier, dll.',
              prefixIcon: Icons.notes_outlined,
              maxLines: 2,
              validator: (v) {
                if (_selectedType == 'out' && (v == null || v.trim().isEmpty)) {
                  return 'Catatan alasan stok keluar/minus wajib diisi!';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  bool submit() {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedProductId == null) return false;
      widget.onSubmit(
        produkId: _selectedProductId!,
        type: _selectedType,
        qty: int.parse(_qtyController.text),
        tanggal: _dateController.text,
        catatan: _notesController.text,
      );
      return true;
    }
    return false;
  }
}
