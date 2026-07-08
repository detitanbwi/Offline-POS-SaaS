import 'package:flutter/material.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditDialog(BuildContext context, [Product? product]) {
    final categoryState = ref.read(categoryNotifierProvider);
    final activeCategories = categoryState.allCategories.where((c) => c.isActive).toList();

    if (activeCategories.isEmpty) {
      AppSnackbar.showWarning(context, 'Silakan buat Kategori Aktif terlebih dahulu sebelum menambah produk!');
      return;
    }

    final formKey = GlobalKey<ProductFormState>();

    AppDialog.show(
      context: context,
      title: product == null ? 'Tambah Produk' : 'Ubah Produk',
      confirmText: 'Simpan',
      content: ProductForm(
        key: formKey,
        product: product,
        categories: categoryState.allCategories,
        onSubmit: ({
          required String nama,
          required String kategoriId,
          required double harga,
          required int stok,
          required int status,
        }) async {
          Navigator.pop(context); // close dialog

          bool success;
          if (product == null) {
            success = await ref.read(productNotifierProvider.notifier).addProduct(
                  nama: nama,
                  kategoriId: kategoriId,
                  harga: harga,
                  stok: stok,
                  status: status,
                );
          } else {
            success = await ref.read(productNotifierProvider.notifier).updateProduct(
                  id: product.id,
                  nama: nama,
                  kategoriId: kategoriId,
                  harga: harga,
                  status: status,
                );
          }

          if (!mounted) return;
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
      onConfirm: () {
        formKey.currentState?.submit();
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

        if (!mounted) return;
        final state = ref.read(productNotifierProvider);
        if (success) {
          AppSnackbar.showSuccess(context, 'Produk "${product.nama}" berhasil dihapus!');
        } else if (state.errorMessage != null) {
          AppSnackbar.showError(context, state.errorMessage!);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(productNotifierProvider);
    final categoryState = ref.watch(categoryNotifierProvider);
    final notifier = ref.read(productNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Kelola Produk'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
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
                  AppTextField(
                    controller: _searchController,
                    labelText: 'Cari Produk',
                    prefixIcon: Icons.search,
                    onChanged: (val) => notifier.setSearchQuery(val),
                  ),
                  const SizedBox(height: 12),
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
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Status filters
                      Row(
                        children: [
                          _FilterChip(
                            label: 'Semua Status',
                            isSelected: state.statusFilter == null,
                            onTap: () => notifier.setStatusFilter(null),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Aktif',
                            isSelected: state.statusFilter == 1,
                            onTap: () => notifier.setStatusFilter(1),
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Nonaktif',
                            isSelected: state.statusFilter == 0,
                            onTap: () => notifier.setStatusFilter(0),
                          ),
                        ],
                      ),
                      // Sorting menu
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.sort, color: AppColors.primary),
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
                      : ResponsiveLayout(
                          mobile: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.m),
                            itemCount: state.filteredProducts.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final product = state.filteredProducts[index];
                              return _ProductItemRow(
                                product: product,
                                onEdit: () => _showAddEditDialog(context, product),
                                onDelete: () => _confirmDelete(context, product),
                              );
                            },
                          ),
                          tablet: GridView.builder(
                            padding: const EdgeInsets.all(AppSpacing.m),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.8,
                            ),
                            itemCount: state.filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = state.filteredProducts[index];
                              return _ProductItemCard(
                                product: product,
                                onEdit: () => _showAddEditDialog(context, product),
                                onDelete: () => _confirmDelete(context, product),
                              );
                            },
                          ),
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
          fontSize: 12,
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
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductItemRow({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderSide: const BorderSide(color: AppColors.divider),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (product.isActive ? AppColors.primary : AppColors.disabled).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: product.isActive ? AppColors.primary : AppColors.disabled,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.nama,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 16,
                    decoration: product.isActive ? null : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${product.kategoriNama ?? 'Tanpa Kategori'} • Stok: ${product.stok}',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.format(product.harga),
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.secondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _ProductItemCard extends StatelessWidget {
  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductItemCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      borderSide: const BorderSide(color: AppColors.divider),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.nama,
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 15,
                        decoration: product.isActive ? null : TextDecoration.lineThrough,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.kategoriNama ?? 'Tanpa Kategori',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (product.stok > 0 ? AppColors.success : AppColors.error).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Stok: ${product.stok}',
                  style: TextStyle(
                    color: product.stok > 0 ? AppColors.success : AppColors.error,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyFormatter.format(product.harga),
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.secondary,
                  fontSize: 14,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
                    onPressed: onEdit,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                    onPressed: onDelete,
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

