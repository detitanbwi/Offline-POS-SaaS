import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';

import '../../../category/application/category_notifier.dart';
import '../../../product/application/product_notifier.dart';
import '../../../product/domain/models/product.dart';
import '../../application/cart_notifier.dart';

class CashierCatalogSection extends ConsumerStatefulWidget {
  const CashierCatalogSection({super.key});

  @override
  ConsumerState<CashierCatalogSection> createState() => _CashierCatalogSectionState();
}

class _CashierCatalogSectionState extends ConsumerState<CashierCatalogSection> {
  final _searchController = TextEditingController();
  String? _selectedCategoryId;
  Timer? _debounceTimer;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query.trim().toLowerCase();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productNotifierProvider);
    final categoryState = ref.watch(categoryNotifierProvider);

    // Filter products by category & search query
    List<Product> filteredProducts = productState.allProducts.where((p) {
      if (!p.isActive) return false;
      if (_selectedCategoryId != null && p.kategoriId != _selectedCategoryId) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        return p.nama.toLowerCase().contains(_searchQuery);
      }
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search bar
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Cari produk atau kode...',
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        SizedBox(height: AppSpacing.m),

        // Category filter chips
        if (categoryState.allCategories.isNotEmpty) ...[
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text('Semua'),
                    selected: _selectedCategoryId == null,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _selectedCategoryId == null ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedCategoryId = null);
                    },
                  ),
                ),
                ...categoryState.allCategories.map((cat) {
                  final isSelected = _selectedCategoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(cat.nama),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12.sp,
                      ),
                      onSelected: (_) {
                        setState(() {
                          _selectedCategoryId = isSelected ? null : cat.id;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.m),
        ],

        // Product Grid
        Expanded(
          child: productState.isLoading && productState.allProducts.isEmpty
              ? const AppLoading(message: 'Memuat produk...')
              : filteredProducts.isEmpty
                  ? const AppEmptyState(
                      title: 'Produk Tidak Ditemukan',
                      description: 'Coba ubah kata kunci pencarian atau filter kategori.',
                      icon: Icons.inventory_2_outlined,
                    )
                  : GridView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 160,
                        mainAxisSpacing: AppSpacing.s,
                        crossAxisSpacing: AppSpacing.s,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                            final isOutOfStock = product.stok != -1 && product.stok <= 0;

                            return InkWell(
                              onTap: isOutOfStock
                                  ? null
                                  : () {
                                      ref.read(cartNotifierProvider.notifier).addItem(product);
                                    },
                              borderRadius: BorderRadius.circular(12),
                              child: AppCard(
                                color: isOutOfStock
                                    ? AppColors.background
                                    : AppColors.surface,
                                borderSide: BorderSide(
                                  color: isOutOfStock ? AppColors.divider : AppColors.divider.withValues(alpha: 0.5),
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Center(
                                          child: product.image != null && product.image!.isNotEmpty
                                              ? (Validators.isValidWebUrl(product.image!)
                                                  ? Image.network(
                                                      product.image!,
                                                      fit: BoxFit.cover,
                                                      width: double.infinity,
                                                      height: double.infinity,
                                                      cacheWidth: 300,
                                                      errorBuilder: (context, error, stackTrace) => Icon(
                                                        Icons.fastfood_rounded,
                                                        size: 36,
                                                        color: isOutOfStock
                                                            ? AppColors.textSecondary.withValues(alpha: 0.4)
                                                            : AppColors.primary,
                                                      ),
                                                    )
                                                  : Validators.isValidLocalFile(product.image!)
                                                      ? Image.file(
                                                          File(product.image!),
                                                          fit: BoxFit.cover,
                                                          width: double.infinity,
                                                          height: double.infinity,
                                                          cacheWidth: 300,
                                                          errorBuilder: (context, error, stackTrace) => Icon(
                                                            Icons.fastfood_rounded,
                                                            size: 36,
                                                            color: isOutOfStock
                                                                ? AppColors.textSecondary.withValues(alpha: 0.4)
                                                                : AppColors.primary,
                                                          ),
                                                        )
                                                      : Icon(
                                                          Icons.fastfood_rounded,
                                                          size: 36,
                                                          color: isOutOfStock
                                                              ? AppColors.textSecondary.withValues(alpha: 0.4)
                                                              : AppColors.primary,
                                                        ))
                                              : Icon(
                                                  Icons.fastfood_rounded,
                                                  size: 36,
                                                  color: isOutOfStock
                                                      ? AppColors.textSecondary.withValues(alpha: 0.4)
                                                      : AppColors.primary,
                                                ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      product.nama,
                                      style: AppTypography.titleMedium.copyWith(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.bold,
                                        color: isOutOfStock ? AppColors.textSecondary : AppColors.textPrimary,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              CurrencyFormatter.format(product.harga),
                                              style: TextStyle(
                                                color: isOutOfStock ? AppColors.textSecondary : AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (product.stok != -1)
                                          Flexible(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                isOutOfStock ? 'Habis' : 'Stok: ${product.stok}',
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  color: isOutOfStock ? AppColors.error : AppColors.textSecondary,
                                                  fontWeight: isOutOfStock ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        ),
      ],
    );
  }
}
