import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../application/category_notifier.dart';
import '../../domain/models/category.dart';
import '../widgets/category_form.dart';

class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key});

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddEditDialog(BuildContext context, [Category? category]) {
    final formKey = GlobalKey<CategoryFormState>();
    
    AppDialog.show(
      context: context,
      title: category == null ? 'Tambah Kategori' : 'Ubah Kategori',
      confirmText: 'Simpan',
      content: CategoryForm(
        key: formKey,
        category: category,
        onSubmit: (names, status) async {
          Navigator.pop(context); // close dialog
          
          bool success;
          if (category == null) {
            success = await ref.read(categoryNotifierProvider.notifier).addCategories(names);
          } else {
            success = await ref.read(categoryNotifierProvider.notifier).updateCategory(category.id, names.first, status);
          }

          if (!mounted) return;
          final state = ref.read(categoryNotifierProvider);
          if (success) {
            AppSnackbar.showSuccess(
              context,
              category == null ? 'Kategori berhasil ditambahkan!' : 'Kategori berhasil diperbarui!',
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

  void _confirmDelete(BuildContext context, Category category) {
    AppDialog.showConfirmDelete(
      context: context,
      title: 'Hapus Kategori',
      itemName: category.nama,
      onDelete: () async {
        Navigator.pop(context); // close dialog
        final success = await ref.read(categoryNotifierProvider.notifier).deleteCategory(category.id);
        
        if (!mounted) return;
        final state = ref.read(categoryNotifierProvider);
        if (success) {
          AppSnackbar.showSuccess(context, 'Kategori "${category.nama}" berhasil dihapus!');
        } else if (state.errorMessage != null) {
          AppSnackbar.showError(context, state.errorMessage!);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(categoryNotifierProvider);
    final notifier = ref.read(categoryNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Kelola Kategori'),
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
            // Search and Filter Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.m),
              child: Column(
                children: [
                  AppTextField(
                    controller: _searchController,
                    labelText: 'Cari Kategori',
                    prefixIcon: Icons.search,
                    onChanged: (val) => notifier.setSearchQuery(val),
                  ),
                  const SizedBox(height: 12),
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
                        ),
                      ),
                      // Sorting action
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
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: state.isLoading
                  ? const AppLoading(message: 'Memproses data...')
                  : state.filteredCategories.isEmpty
                      ? AppEmptyState(
                          title: 'Kategori Kosong',
                          description: _searchController.text.isNotEmpty
                              ? 'Tidak ada kategori yang cocok dengan kata kunci Anda.'
                              : 'Tambahkan kategori produk pertama Anda sekarang.',
                          icon: Icons.category_outlined,
                          actionText: _searchController.text.isNotEmpty ? null : 'Tambah Kategori',
                          onActionPressed: () => _showAddEditDialog(context),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.m),
                          itemCount: state.filteredCategories.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final category = state.filteredCategories[index];
                            return _CategoryItem(
                              category: category,
                              onEdit: () => _showAddEditDialog(context, category),
                              onDelete: () => _confirmDelete(context, category),
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

class _CategoryItem extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryItem({
    required this.category,
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
              color: (category.isActive ? AppColors.success : AppColors.disabled).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.folder_open_rounded,
              color: category.isActive ? AppColors.success : AppColors.disabled,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.nama,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 16,
                    decoration: category.isActive ? null : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category.isActive ? 'Status: Aktif' : 'Status: Nonaktif',
                  style: AppTypography.bodyMedium.copyWith(
                    color: category.isActive ? AppColors.success : AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
            onPressed: onEdit,
            tooltip: 'Ubah',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
            onPressed: onDelete,
            tooltip: 'Hapus',
          ),
        ],
      ),
    );
  }
}

// Removed shadow state class to use public CategoryFormState from widgets/category_form.dart
