import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  String? _productError;

  // Filter products: Only active, non-package, and with stock tracking (stok != -1)
  List<Product> get _stockableProducts => widget.products
      .where((p) => p.isActive && !p.isPackage && p.stok != -1)
      .toList();

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController();
    _notesController = TextEditingController();
    _selectedDate = DateTime.now();
    _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(_selectedDate));

    final stockables = _stockableProducts;
    if (stockables.isNotEmpty) {
      _selectedProductId = stockables.first.id;
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

  Future<void> _showProductSearchPicker(BuildContext context) async {
    final availableProducts = _stockableProducts;
    final searchCtrl = TextEditingController();
    String searchQuery = '';

    final selected = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = availableProducts.where((p) {
              if (searchQuery.isNotEmpty) {
                final q = searchQuery.toLowerCase();
                final nameMatch = p.nama.toLowerCase().contains(q);
                final catMatch = (p.kategoriNama ?? '').toLowerCase().contains(q);
                return nameMatch || catMatch;
              }
              return true;
            }).toList();

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar & Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.divider,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Pilih Produk Stok (${filtered.length})',
                              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () => Navigator.pop(modalContext),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Search Field
                        TextField(
                          controller: searchCtrl,
                          autofocus: true,
                          decoration: InputDecoration(
                            hintText: 'Cari nama atau kategori produk...',
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 20),
                            suffixIcon: searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () {
                                      searchCtrl.clear();
                                      setModalState(() => searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.background,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) {
                            setModalState(() => searchQuery = val.trim());
                          },
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, color: AppColors.divider),

                  // Results list
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                                const SizedBox(height: 8),
                                Text(
                                  'Produk stok tidak ditemukan',
                                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (ctx, idx) => const SizedBox(height: 4),
                            itemBuilder: (ctx, i) {
                              final p = filtered[i];
                              final isSelected = p.id == _selectedProductId;

                              return InkWell(
                                onTap: () => Navigator.pop(modalContext, p),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surface,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected ? AppColors.primary : AppColors.divider.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                        child: const Icon(
                                          Icons.inventory_2_rounded,
                                          size: 18,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.nama,
                                              style: AppTypography.titleMedium.copyWith(
                                                fontSize: 13.sp,
                                                fontWeight: FontWeight.bold,
                                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                              ),
                                            ),
                                            Text(
                                              '${p.kategoriNama ?? "Tanpa Kategori"} • Stok: ${p.stok} pcs',
                                              style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.textSecondary,
                                                fontSize: 11.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        isSelected ? Icons.check_circle : Icons.chevron_right_rounded,
                                        size: 20,
                                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected != null) {
      setState(() {
        _selectedProductId = selected.id;
        _productError = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stockables = _stockableProducts;
    final selectedProduct = stockables.where((p) => p.id == _selectedProductId).firstOrNull;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Jenis Mutasi Stok (Segmented Toggle Button)
            Text(
              'Jenis Mutasi Stok',
              style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  // Option: Stok Masuk
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedType = 'in'),
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedType == 'in' ? AppColors.success.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_circle_outline_rounded,
                              size: 16,
                              color: _selectedType == 'in' ? AppColors.success : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Stok Masuk (+)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: _selectedType == 'in' ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedType == 'in' ? AppColors.success : AppColors.textSecondary,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(width: 1, height: 36, color: AppColors.divider),
                  // Option: Stok Keluar
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedType = 'out'),
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedType == 'out' ? AppColors.error.withValues(alpha: 0.12) : Colors.transparent,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.remove_circle_outline_rounded,
                              size: 16,
                              color: _selectedType == 'out' ? AppColors.error : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Stok Keluar (-)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium.copyWith(
                                  fontWeight: _selectedType == 'out' ? FontWeight.bold : FontWeight.normal,
                                  color: _selectedType == 'out' ? AppColors.error : AppColors.textSecondary,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Product Picker with Search
            Text(
              'Pilih Produk (Khusus Produk Stok)',
              style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _showProductSearchPicker(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _productError != null ? AppColors.error : AppColors.divider,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: selectedProduct != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  selectedProduct.nama,
                                  style: AppTypography.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${selectedProduct.kategoriNama ?? "Tanpa Kategori"} • Stok saat ini: ${selectedProduct.stok} pcs',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.sp,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            )
                          : Text(
                              'Ketuk untuk cari dan pilih produk...',
                              style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                            ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.search_rounded, color: AppColors.primary, size: 18),
                    ),
                  ],
                ),
              ),
            ),
            if (_productError != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  _productError!,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.error, fontSize: 11.sp),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // 3. Jumlah Qty
            AppTextField(
              controller: _qtyController,
              labelText: _selectedType == 'in' ? 'Jumlah Masuk (Qty pcs)' : 'Jumlah Keluar / Minus (Qty pcs)',
              hintText: _selectedType == 'in' ? 'Masukkan jumlah produk masuk' : 'Masukkan jumlah produk berkurang',
              prefixIcon: _selectedType == 'in' ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                final err = Validators.integer(v, 'Jumlah Qty');
                if (err != null) return err;
                final val = int.tryParse(v!);
                if (val == null || val <= 0) return 'Jumlah Qty harus lebih besar dari 0';
                if (val > 999999) return 'Jumlah Qty maksimal 999.999';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 4. Tanggal Transaksi Stok
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

            // 5. Catatan
            AppTextField(
              controller: _notesController,
              labelText: _selectedType == 'out' ? 'Catatan Pengurangan (Wajib)' : 'Catatan (Opsional)',
              hintText: _selectedType == 'out'
                  ? 'Contoh: Barang rusak, kadaluarsa, hilang, atau koreksi fisik.'
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
    setState(() {
      _productError = _selectedProductId == null ? 'Produk stok wajib dipilih!' : null;
    });

    if ((_formKey.currentState?.validate() ?? false) && _selectedProductId != null) {
      widget.onSubmit(
        produkId: _selectedProductId!,
        type: _selectedType,
        qty: int.parse(_qtyController.text),
        tanggal: _dateController.text,
        catatan: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      return true;
    }
    return false;
  }
}
