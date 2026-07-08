import 'dart:io';
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
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _confirmBulkDelete(BuildContext context, List<Category> categories) {
    AppDialog.show(
      context: context,
      title: 'Hapus Masal Kategori',
      message: 'Apakah Anda yakin ingin menghapus ${_selectedIds.length} kategori terpilih? Kategori yang masih digunakan oleh produk tidak akan terhapus.',
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
          final success = await ref.read(categoryNotifierProvider.notifier).deleteCategory(id);
          if (success) {
            deletedCount++;
          } else {
            failedCount++;
          }
        }
        
        if (!mounted) return;
        
        if (failedCount > 0) {
          AppSnackbar.showWarning(
            context,
            'Berhasil menghapus $deletedCount kategori. $failedCount kategori gagal dihapus (karena masih digunakan oleh produk).',
          );
        } else {
          AppSnackbar.showSuccess(context, '$deletedCount kategori berhasil dihapus.');
        }
      },
    );
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
        onSubmit: (names, status, image) async {
          Navigator.pop(context); // close dialog
          
          bool success;
          if (category == null) {
            if (names.length == 1) {
              success = await ref.read(categoryNotifierProvider.notifier).addCategory(names.first, image: image);
            } else {
              success = await ref.read(categoryNotifierProvider.notifier).addCategories(names);
            }
          } else {
            success = await ref.read(categoryNotifierProvider.notifier).updateCategory(category.id, names.first, status, image: image);
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
        title: Text(_isSelectionMode ? 'Pilih Kategori' : 'Kelola Kategori'),
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
                  if (_isSelectionMode) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: state.filteredCategories.isNotEmpty &&
                              _selectedIds.length == state.filteredCategories.length,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.addAll(state.filteredCategories.map((c) => c.id));
                              } else {
                                _selectedIds.clear();
                              }
                            });
                          },
                        ),
                        const Text('Pilih Semua', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 16),
                        Text('${_selectedIds.length} Terpilih'),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _selectedIds.isEmpty
                              ? null
                              : () => _confirmBulkDelete(context, state.filteredCategories),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16),
                          label: const Text('Hapus', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ),
                  ],

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
                            final isSelected = _selectedIds.contains(category.id);
                            return _CategoryItem(
                              category: category,
                              isSelectionMode: _isSelectionMode,
                              isSelected: isSelected,
                              onSelectedChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedIds.add(category.id);
                                  } else {
                                    _selectedIds.remove(category.id);
                                  }
                                });
                              },
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
  final bool isSelectionMode;
  final bool isSelected;
  final ValueChanged<bool?>? onSelectedChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryItem({
    required this.category,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectedChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    final hasImg = category.image != null && category.image!.isNotEmpty;
    if (hasImg) {
      if (category.image!.startsWith('http')) {
        imageWidget = Image.network(
          category.image!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.folder_open_rounded, color: AppColors.primary),
        );
      } else {
        imageWidget = Image.file(
          File(category.image!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.folder_open_rounded, color: AppColors.primary),
        );
      }
    } else {
      imageWidget = Icon(
        Icons.folder_open_rounded,
        color: category.isActive ? AppColors.success : AppColors.disabled,
        size: 24,
      );
    }

    return AppCard(
      onTap: isSelectionMode ? () => onSelectedChanged?.call(!isSelected) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderSide: const BorderSide(color: AppColors.divider),
      child: Row(
        children: [
          if (isSelectionMode)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Checkbox(
                value: isSelected,
                onChanged: onSelectedChanged,
              ),
            )
          else
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (category.isActive ? AppColors.success : AppColors.disabled).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Center(child: imageWidget),
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
          if (!isSelectionMode) ...[
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
        ],
      ),
    );
  }
}

// Removed shadow state class to use public CategoryFormState from widgets/category_form.dart
