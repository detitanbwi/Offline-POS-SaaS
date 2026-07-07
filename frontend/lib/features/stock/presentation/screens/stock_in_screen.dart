import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../../../product/application/product_notifier.dart';
import '../../application/stock_notifier.dart';
import '../widgets/stock_in_form.dart';

class StockInScreen extends ConsumerStatefulWidget {
  const StockInScreen({super.key});

  @override
  ConsumerState<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends ConsumerState<StockInScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddDialog(BuildContext context) {
    // Make sure product notifier has products loaded
    final productState = ref.read(productNotifierProvider);
    final activeProducts = productState.allProducts.where((p) => p.isActive).toList();

    if (activeProducts.isEmpty) {
      AppSnackbar.showWarning(context, 'Tidak ada Produk Aktif. Silakan tambah produk terlebih dahulu!');
      return;
    }

    final formKey = GlobalKey<_StockInFormState>();

    AppDialog.show(
      context: context,
      title: 'Catat Stok Masuk',
      confirmText: 'Simpan',
      content: StockInForm(
        key: formKey,
        products: productState.allProducts,
        onSubmit: ({
          required String produkId,
          required int qty,
          required String tanggal,
          String? catatan,
        }) async {
          Navigator.pop(context); // close dialog

          final success = await ref.read(stockNotifierProvider.notifier).addStockIn(
                produkId: produkId,
                qty: qty,
                tanggal: tanggal,
                catatan: catatan,
              );

          if (!mounted) return;
          final state = ref.read(stockNotifierProvider);
          if (success) {
            AppSnackbar.showSuccess(context, 'Stok masuk berhasil dicatat!');
          } else if (state.errorMessage != null) {
            AppSnackbar.showError(context, state.errorMessage!);
          }
        },
      ),
      onConfirm: () {
        formKey.currentState?.submit();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stockNotifierProvider);
    final notifier = ref.read(stockNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Stok Masuk (Stock In)'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_circle_outline),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.m),
              child: AppTextField(
                controller: _searchController,
                labelText: 'Cari Riwayat Stok',
                prefixIcon: Icons.search,
                onChanged: (val) => notifier.setSearchQuery(val),
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: state.isLoading
                  ? const AppLoading(message: 'Memuat data riwayat stok...')
                  : state.filteredStockIn.isEmpty
                      ? AppEmptyState(
                          title: 'Riwayat Stok Kosong',
                          description: _searchController.text.isNotEmpty
                              ? 'Tidak ada riwayat stok yang cocok dengan pencarian Anda.'
                              : 'Belum ada transaksi pencatatan stok masuk.',
                          icon: Icons.assignment_outlined,
                          actionText: _searchController.text.isNotEmpty ? null : 'Catat Stok Masuk',
                          onActionPressed: () => _showAddDialog(context),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.m),
                          itemCount: state.filteredStockIn.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final log = state.filteredStockIn[index];
                            return AppCard(
                              padding: const EdgeInsets.all(16),
                              borderSide: const BorderSide(color: AppColors.divider),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.add_box_outlined,
                                      color: AppColors.success,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          log.produkNama ?? 'Produk Tidak Diketahui',
                                          style: AppTypography.titleMedium.copyWith(fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        if (log.catatan != null && log.catatan!.isNotEmpty) ...[
                                          Text(
                                            log.catatan!,
                                            style: AppTypography.bodyMedium.copyWith(
                                              color: AppColors.textSecondary,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                        ],
                                        Text(
                                          'Tanggal: ${log.tanggal}',
                                          style: AppTypography.bodyMedium.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '+${log.qty}',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// Global key state hook helper (nested in stock_in_form.dart)
class _StockInFormState extends State<StockInForm> {
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
          DropdownButtonFormField<String>(
            value: _selectedProductId,
            decoration: const InputDecoration(
              labelText: 'Pilih Produk',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
            items: activeProducts.map((p) {
              return DropdownMenuItem<String>(
                value: p.id,
                child: Text('${p.nama} (Stok saat ini: ${p.stok})'),
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
            hintText: 'Contoh: Restock barang supplier',
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
