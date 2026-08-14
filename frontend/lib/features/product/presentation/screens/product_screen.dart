import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/utils/validators.dart';
import '../../../category/application/category_notifier.dart';
import '../../application/product_notifier.dart';
import '../../domain/models/product.dart';
import '../widgets/product_form.dart';

class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key});

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  final _searchController = TextEditingController();
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmBulkDelete(BuildContext context) {
    AppDialog.show(
      context: context,
      title: 'Hapus Masal Produk',
      message: 'Apakah Anda yakin ingin menghapus ${_selectedIds.length} produk terpilih? Produk yang memiliki transaksi terkait tidak akan terhapus.',
      confirmText: 'Hapus',
      cancelText: 'Batal',
      isDestructive: true,
      onConfirm: () async {
        Navigator.pop(context); // close dialog
        
        final idsToDelete = _selectedIds.toList();
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });
        
        int deletedCount = 0;
        int failedCount = 0;
        
        for (final id in idsToDelete) {
          final success = await ref.read(productNotifierProvider.notifier).deleteProduct(id);
          if (success) {
            deletedCount++;
          } else {
            failedCount++;
          }
        }
        
        if (!context.mounted) return;
        
        if (failedCount > 0) {
          AppSnackbar.showWarning(
            context,
            'Berhasil menghapus $deletedCount produk. $failedCount produk gagal dihapus (karena terdapat transaksi terkait).',
          );
        } else {
          AppSnackbar.showSuccess(context, '$deletedCount produk berhasil dihapus.');
        }
      },
    );
  }

  void _showAddEditDialog(BuildContext context, [Product? product]) {
    final categoryState = ref.read(categoryNotifierProvider);
    final activeCategories = categoryState.allCategories.where((c) => c.isActive).toList();

    if (activeCategories.isEmpty) {
      AppSnackbar.showWarning(context, 'Silakan buat Kategori Aktif terlebih dahulu sebelum menambah produk!');
      return;
    }

    final formKey = GlobalKey<ProductFormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isSaving = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return AppDialog(
              title: product == null ? 'Tambah Produk' : 'Ubah Produk',
              confirmText: 'Simpan',
              isLoading: isSaving,
              content: SizedBox(
                width: 420,
                child: ProductForm(
                  key: formKey,
                  product: product,
                  categories: categoryState.allCategories,
                  onSubmit: ({
                    required String nama,
                    required String kategoriId,
                    required double harga,
                    required int stok,
                    required int status,
                    String? image,
                  }) async {
                    if (isSaving) return;
                    
                    // Unfocus keyboard to start hiding animation smoothly
                    FocusScope.of(context).unfocus();
                    
                    setState(() => isSaving = true);
                    
                    // Yield control to the event loop so the UI can render the loading indicator
                    // and keyboard hide animation can complete without dropping frames.
                    await Future.delayed(const Duration(milliseconds: 300));

                    bool success;
                    if (product == null) {
                      success = await ref.read(productNotifierProvider.notifier).addProduct(
                            nama: nama,
                            kategoriId: kategoriId,
                            harga: harga,
                            stok: stok,
                            status: status,
                            image: image,
                          );
                    } else {
                      success = await ref.read(productNotifierProvider.notifier).updateProduct(
                            id: product.id,
                            nama: nama,
                            kategoriId: kategoriId,
                            harga: harga,
                            stok: stok,
                            status: status,
                            image: image,
                          );
                    }

                    if (!context.mounted) return;
                    
                    // Close the dialog only after processing is done
                    Navigator.pop(context);

                    final state = ref.read(productNotifierProvider);
                    if (success) {
                      AppSnackbar.showSuccess(
                        context,
                        product == null ? 'Produk berhasil ditambahkan!' : 'Produk berhasil diperbarui!',
                      );
                    } else if (state.errorMessage != null) {
                      AppSnackbar.showError(context, state.errorMessage!);
                    }
                  },
                ),
              ),
              onConfirm: () {
                formKey.currentState?.submit();
              },
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Product product) {
    AppDialog.showConfirmDelete(
      context: context,
      title: 'Hapus Produk',
      itemName: product.nama,
      onDelete: () async {
        Navigator.pop(context); // close dialog
        final success = await ref.read(productNotifierProvider.notifier).deleteProduct(product.id);

        if (!context.mounted) return;
        final state = ref.read(productNotifierProvider);
        if (success) {
          AppSnackbar.showSuccess(context, 'Produk "${product.nama}" berhasil dihapus!');
        } else if (state.errorMessage != null) {
          AppSnackbar.showError(context, state.errorMessage!);
        }
      },
    );
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final state = ref.watch(productNotifierProvider);
          final categoryState = ref.watch(categoryNotifierProvider);
          final notifier = ref.read(productNotifierProvider.notifier);

          return SafeArea(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.l,
                AppSpacing.l,
                AppSpacing.l,
                AppSpacing.l + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Filter & Urutan Produk', style: AppTypography.titleLarge),
                        IconButton(
                          icon: Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    SizedBox(height: 12),
                    Text('Filter Kategori', style: AppTypography.titleMedium.copyWith(fontSize: 14.sp)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _FilterChip(
                          label: 'Semua Kategori',
                          isSelected: state.categoryIdFilter == null,
                          onTap: () => notifier.setCategoryFilter(null),
                        ),
                        ...categoryState.allCategories.map((cat) {
                          return _FilterChip(
                            label: cat.nama,
                            isSelected: state.categoryIdFilter == cat.id,
                            onTap: () => notifier.setCategoryFilter(cat.id),
                          );
                        }),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text('Filter Status', style: AppTypography.titleMedium.copyWith(fontSize: 14.sp)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        _FilterChip(
                          label: 'Semua Status',
                          isSelected: state.statusFilter == null,
                          onTap: () => notifier.setStatusFilter(null),
                        ),
                        SizedBox(width: 8),
                        _FilterChip(
                          label: 'Aktif',
                          isSelected: state.statusFilter == 1,
                          onTap: () => notifier.setStatusFilter(1),
                        ),
                        SizedBox(width: 8),
                        _FilterChip(
                          label: 'Nonaktif',
                          isSelected: state.statusFilter == 0,
                          onTap: () => notifier.setStatusFilter(0),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Text('Urutan Produk', style: AppTypography.titleMedium.copyWith(fontSize: 14.sp)),
                    SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('Nama A-Z'),
                          selected: state.sortBy == 'name_asc',
                          onSelected: (_) => notifier.setSortBy('name_asc'),
                        ),
                        ChoiceChip(
                          label: Text('Nama Z-A'),
                          selected: state.sortBy == 'name_desc',
                          onSelected: (_) => notifier.setSortBy('name_desc'),
                        ),
                        ChoiceChip(
                          label: Text('Harga Termurah'),
                          selected: state.sortBy == 'price_asc',
                          onSelected: (_) => notifier.setSortBy('price_asc'),
                        ),
                        ChoiceChip(
                          label: Text('Harga Termahal'),
                          selected: state.sortBy == 'price_desc',
                          onSelected: (_) => notifier.setSortBy('price_desc'),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('Terapkan Filter'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productNotifierProvider);
    final categoryState = ref.watch(categoryNotifierProvider);
    final notifier = ref.read(productNotifierProvider.notifier);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isSelectionMode ? 'Pilih Produk' : 'Kelola Produk',
              style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
            if (!_isSelectionMode)
              Text(
                'Atur dan pantau daftar produk Anda',
                style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 12.sp),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist_rounded),
            onPressed: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                _selectedIds.clear();
              });
            },
            tooltip: _isSelectionMode ? 'Batal' : 'Pilih Banyak',
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddEditDialog(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: Icon(Icons.add),
            ),
      body: SafeArea(
        child: Column(
          children: [
            // Header Search & Filters
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                children: [
                  if (isLandscape) ...[
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _searchController,
                            labelText: 'Cari Produk',
                            prefixIcon: Icons.search,
                            onChanged: (val) => notifier.setSearchQuery(val),
                            debounceDuration: const Duration(milliseconds: 500),
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (state.categoryIdFilter != null || state.statusFilter != null)
                                ? AppColors.primary
                                : AppColors.surface,
                            foregroundColor: (state.categoryIdFilter != null || state.statusFilter != null)
                                ? Colors.white
                                : AppColors.textPrimary,
                            side: const BorderSide(color: AppColors.divider),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: Icon(Icons.tune_rounded, size: 20),
                          label: Text(
                            (state.categoryIdFilter != null || state.statusFilter != null)
                                ? 'Filter (Aktif)'
                                : 'Filter & Urutkan',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _showFilterBottomSheet(context),
                        ),
                      ],
                    ),
                  ] else ...[
                    AppTextField(
                      controller: _searchController,
                      labelText: 'Cari Produk',
                      prefixIcon: Icons.search,
                      onChanged: (val) => notifier.setSearchQuery(val),
                            debounceDuration: const Duration(milliseconds: 500),
                    ),
                    SizedBox(height: 12),
                    // Categories chips scrollable filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Semua Kategori',
                            isSelected: state.categoryIdFilter == null,
                            onTap: () => notifier.setCategoryFilter(null),
                          ),
                          ...categoryState.allCategories.map((cat) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: _FilterChip(
                                label: cat.nama,
                                isSelected: state.categoryIdFilter == cat.id,
                                onTap: () => notifier.setCategoryFilter(cat.id),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Status filters
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _FilterChip(
                                  label: 'Semua',
                                  isSelected: state.statusFilter == null,
                                  onTap: () => notifier.setStatusFilter(null),
                                ),
                                SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Aktif',
                                  isSelected: state.statusFilter == 1,
                                  onTap: () => notifier.setStatusFilter(1),
                                ),
                                SizedBox(width: 8),
                                _FilterChip(
                                  label: 'Nonaktif',
                                  isSelected: state.statusFilter == 0,
                                  onTap: () => notifier.setStatusFilter(0),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Sorting menu
                        PopupMenuButton<String>(
                          icon: Icon(Icons.sort, color: AppColors.primary),
                          tooltip: 'Urutan',
                          onSelected: (val) => notifier.setSortBy(val),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'name_asc',
                              child: Text('Nama A-Z'),
                            ),
                            const PopupMenuItem(
                              value: 'name_desc',
                              child: Text('Nama Z-A'),
                            ),
                            const PopupMenuItem(
                              value: 'price_asc',
                              child: Text('Harga Termurah'),
                            ),
                            const PopupMenuItem(
                              value: 'price_desc',
                              child: Text('Harga Termahal'),
                            ),
                            const PopupMenuItem(
                              value: 'stock_asc',
                              child: Text('Stok Terendah'),
                            ),
                            const PopupMenuItem(
                              value: 'stock_desc',
                              child: Text('Stok Tertinggi'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                  if (_isSelectionMode) ...[
                    SizedBox(height: 12),
                    const Divider(),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: state.filteredProducts.isNotEmpty &&
                              _selectedIds.length == state.filteredProducts.length,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.addAll(state.filteredProducts.map((p) => p.id));
                              } else {
                                _selectedIds.clear();
                              }
                            });
                          },
                        ),
                        Text('Pilih Semua', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(width: 16),
                        Text('${_selectedIds.length} Terpilih'),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _selectedIds.isEmpty
                              ? null
                              : () => _confirmBulkDelete(context),
                          icon: Icon(Icons.delete_outline_rounded, size: 16),
                          label: Text('Hapus Terpilih', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(),
            // Products List
            Expanded(
              child: state.isLoading
                  ? const AppLoading(message: 'Memuat data produk...')
                  : state.filteredProducts.isEmpty
                      ? AppEmptyState(
                          title: 'Produk Kosong',
                          description: _searchController.text.isNotEmpty
                              ? 'Tidak ada produk yang cocok dengan pencarian Anda.'
                              : 'Silakan tambah produk baru menggunakan tombol tambah.',
                          icon: Icons.inventory_2_outlined,
                          actionText: _searchController.text.isNotEmpty ? null : 'Tambah Produk',
                          onActionPressed: () => _showAddEditDialog(context),
                        )
                      : Builder(
                          builder: (context) {
                            // Group products by category
                            final groupedProducts = <String, List<Product>>{};
                            for (var p in state.filteredProducts) {
                              final catName = p.kategoriNama ?? 'Tanpa Kategori';
                              if (!groupedProducts.containsKey(catName)) {
                                groupedProducts[catName] = [];
                              }
                              groupedProducts[catName]!.add(p);
                            }
                            final groupKeys = groupedProducts.keys.toList();

                            return ResponsiveLayout(
                              mobile: ListView.builder(
                                padding: const EdgeInsets.all(AppSpacing.m).copyWith(bottom: 100),
                                itemCount: groupKeys.length,
                                itemBuilder: (context, index) {
                                  final catName = groupKeys[index];
                                  final products = groupedProducts[catName]!;
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                        child: Text(
                                          '---- $catName',
                                          style: AppTypography.titleMedium.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      ...products.map((product) {
                                        final isSelected = _selectedIds.contains(product.id);
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 8.0),
                                          child: _ProductItemRow(
                                            product: product,
                                            isSelectionMode: _isSelectionMode,
                                            isSelected: isSelected,
                                            onSelectedChanged: (selected) {
                                              setState(() {
                                                if (selected == true) {
                                                  _selectedIds.add(product.id);
                                                } else {
                                                  _selectedIds.remove(product.id);
                                                }
                                              });
                                            },
                                            onEdit: () => _showAddEditDialog(context, product),
                                            onDelete: () => _confirmDelete(context, product),
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                },
                              ),
                              tablet: LayoutBuilder(
                                builder: (context, constraints) {
                                  final crossAxisCount = constraints.maxWidth >= 900 ? 6 : 5;
                                  
                                  return ListView.builder(
                                    padding: const EdgeInsets.all(AppSpacing.m).copyWith(bottom: 100),
                                    itemCount: groupKeys.length,
                                    itemBuilder: (context, index) {
                                      final catName = groupKeys[index];
                                      final products = groupedProducts[catName]!;
                                      
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                                            child: Text(
                                              '---- $catName',
                                              style: AppTypography.titleMedium.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          LayoutBuilder(
                                            builder: (context, rowConstraints) {
                                              final itemWidth = (rowConstraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;
                                              return Wrap(
                                                spacing: 12,
                                                runSpacing: 12,
                                                children: products.map((product) {
                                                  final isSelected = _selectedIds.contains(product.id);
                                                  return SizedBox(
                                                    width: itemWidth - 0.01,
                                                    child: _ProductItemCard(
                                                      product: product,
                                                      isSelectionMode: _isSelectionMode,
                                                      isSelected: isSelected,
                                                      onSelectedChanged: (selected) {
                                                        setState(() {
                                                          if (selected == true) {
                                                            _selectedIds.add(product.id);
                                                          } else {
                                                            _selectedIds.remove(product.id);
                                                          }
                                                        });
                                                      },
                                                      onEdit: () => _showAddEditDialog(context, product),
                                                      onDelete: () => _confirmDelete(context, product),
                                                    ),
                                                  );
                                                }).toList(),
                                              );
                                            },
                                          ),
                                          SizedBox(height: 16),
                                        ],
                                      );
                                    },
                                  );
                                },
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13.sp,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppColors.primary : AppColors.divider,
        ),
      ),
    );
  }
}

class _ProductItemRow extends StatelessWidget {
  final Product product;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductItemRow({
    required this.product,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = product.stok == 0;
    
    return AppCard(
      onTap: isSelectionMode ? () => onSelectedChanged?.call(!isSelected) : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      borderSide: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.divider.withValues(alpha: 0.5),
        width: isSelected ? 2 : 1,
      ),
      color: isSelected ? AppColors.primaryContainer : Colors.white,
      child: Stack(
        children: [
          Row(
            children: [
              if (isSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Checkbox(
                    value: isSelected,
                    activeColor: AppColors.primary,
                    onChanged: onSelectedChanged,
                  ),
                ),
              
              // Product Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: (product.isActive ? AppColors.primary : AppColors.disabled).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: product.image != null && product.image!.isNotEmpty
                      ? (Validators.isValidWebUrl(product.image!)
                          ? Image.network(
                              product.image!,
                              fit: BoxFit.cover,
                              cacheWidth: 300,
                              errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
                            )
                          : Validators.isValidLocalFile(product.image!)
                              ? Image.file(
                                  File(product.image!),
                                  fit: BoxFit.cover,
                                  cacheWidth: 300,
                                  errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
                                )
                              : Icon(Icons.broken_image_outlined, color: AppColors.textSecondary))
                      : Icon(
                          Icons.inventory_2_outlined,
                          color: product.isActive ? AppColors.primary.withValues(alpha: 0.5) : AppColors.disabled.withValues(alpha: 0.5),
                          size: 28,
                        ),
                ),
              ),
              SizedBox(width: 12),
              
              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.nama,
                            style: AppTypography.titleMedium.copyWith(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.bold,
                              decoration: product.isActive ? null : TextDecoration.lineThrough,
                              color: product.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOutOfStock)
                           Container(
                             margin: const EdgeInsets.only(left: 4),
                             padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                             decoration: BoxDecoration(
                               color: AppColors.error.withValues(alpha: 0.1),
                               borderRadius: BorderRadius.circular(4),
                             ),
                             child: Text('Habis', style: TextStyle(color: AppColors.error, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                           ),
                      ],
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${product.kategoriNama ?? 'Tanpa Kategori'} • Stok: ${product.stok == -1 ? '∞' : product.stok}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 12.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6),
                    Text(
                      CurrencyFormatter.format(product.harga),
                      style: AppTypography.titleMedium.copyWith(
                        color: product.isActive ? AppColors.secondary : AppColors.textSecondary,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Actions
              if (!isSelectionMode) ...[
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(Icons.edit_rounded, size: 20.sp, color: AppColors.textSecondary),
                      ),
                    ),
                    SizedBox(height: 4),
                    InkWell(
                      onTap: onDelete,
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Icon(Icons.delete_outline_rounded, size: 20.sp, color: AppColors.error.withValues(alpha: 0.8)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          
          if (!product.isActive)
            Positioned(
              right: isSelectionMode ? 0 : 36, // Adjust position based on selection mode
              top: 0,
              child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                 decoration: BoxDecoration(
                   color: AppColors.disabled.withValues(alpha: 0.2),
                   borderRadius: BorderRadius.circular(4),
                 ),
                 child: Text('Nonaktif', style: TextStyle(color: AppColors.textSecondary, fontSize: 10.sp, fontWeight: FontWeight.bold)),
               ),
            ),
        ],
      ),
    );
  }
}

class _ProductItemCard extends StatelessWidget {
  final Product product;
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductItemCard({
    required this.product,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = product.stok == 0;
    
    return AppCard(
      onTap: isSelectionMode ? () => onSelectedChanged?.call(!isSelected) : null,
      padding: EdgeInsets.zero,
      borderSide: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.divider.withValues(alpha: 0.5),
        width: isSelected ? 2 : 1,
      ),
      color: isSelected ? AppColors.primaryContainer : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top section (Image + Status)
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      color: (product.isActive ? AppColors.primary : AppColors.disabled).withValues(alpha: 0.03),
                      child: product.image != null && product.image!.isNotEmpty
                          ? (Validators.isValidWebUrl(product.image!)
                              ? Image.network(
                                  product.image!,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 28),
                                  ),
                                )
                              : Validators.isValidLocalFile(product.image!)
                                  ? Image.file(
                                      File(product.image!),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => Center(
                                        child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 28),
                                      ),
                                    )
                                  : Center(
                                      child: Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 28),
                                    ))
                          : Center(
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: product.isActive ? AppColors.primary.withValues(alpha: 0.4) : AppColors.disabled.withValues(alpha: 0.4),
                                size: 40,
                              ),
                            ),
                    ),
                  ),
                ),
                
                // Badges
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: (product.stok == -1 || product.stok > 0 ? AppColors.success : AppColors.error).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Stok: ${product.stok == -1 ? '∞' : product.stok}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!product.isActive) ...[
                        SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.disabled.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Nonaktif',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                if (isSelectionMode)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: isSelected,
                        activeColor: AppColors.primary,
                        onChanged: onSelectedChanged,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Details section
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        product.nama,
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.bold,
                          decoration: product.isActive ? null : TextDecoration.lineThrough,
                          color: product.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        product.kategoriNama ?? 'Tanpa Kategori',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11.sp,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.format(product.harga),
                    style: AppTypography.titleMedium.copyWith(
                      color: product.isActive ? AppColors.secondary : AppColors.textSecondary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Action Buttons
          if (!isSelectionMode) ...[
            Divider(height: 1, color: AppColors.divider.withValues(alpha: 0.5)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onEdit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Icon(Icons.edit_rounded, size: 16.sp, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                Container(width: 1, height: 24, color: AppColors.divider.withValues(alpha: 0.5)),
                Expanded(
                  child: InkWell(
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Icon(Icons.delete_outline_rounded, size: 16.sp, color: AppColors.error.withValues(alpha: 0.8)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

