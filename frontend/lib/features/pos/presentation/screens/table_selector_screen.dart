import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../product/application/product_notifier.dart';
import '../../application/cart_notifier.dart';
import '../../application/order_notifier.dart';
import '../../../table/application/table_notifier.dart';
import '../../../table/domain/models/table.dart';
import 'pos_screen.dart';

class TableSelectorScreen extends ConsumerStatefulWidget {
  const TableSelectorScreen({super.key});

  @override
  ConsumerState<TableSelectorScreen> createState() => _TableSelectorScreenState();
}

class _TableSelectorScreenState extends ConsumerState<TableSelectorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tableNotifierProvider.notifier).loadTables();
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
      ref.read(productNotifierProvider.notifier).loadProducts();
    });
  }

  Future<void> _handleTableSelected(TableModel table) async {
    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final productState = ref.read(productNotifierProvider);

    orderNotifier.selectTable(table);

    if (table.isOccupied) {
      await orderNotifier.loadActiveOrderForTable(table.id);
      final orderState = ref.read(orderNotifierProvider);
      
      if (orderState.activeOrder != null) {
        cartNotifier.loadDraftItems(orderState.activeOrderItems, productState.allProducts);
      } else {
        cartNotifier.clear();
      }
    } else {
      cartNotifier.clear();
    }

    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PosScreen()),
    ).then((_) {
      ref.read(tableNotifierProvider.notifier).loadTables();
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tableState = ref.watch(tableNotifierProvider);
    final orderState = ref.watch(orderNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Pilih Meja Restoran'),
      ),
      body: SafeArea(
        child: tableState.isLoading && tableState.allTables.isEmpty
            ? const AppLoading(message: 'Memuat data meja...')
            : tableState.allTables.isEmpty
                ? const AppEmptyState(
                    title: 'Belum Ada Meja',
                    description: 'Silakan tambah meja baru di menu "Master Data > Meja Restoran" terlebih dahulu.',
                    icon: Icons.table_restaurant_rounded,
                  )
                : Padding(
                    padding: const EdgeInsets.all(AppSpacing.l),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Pilih Meja untuk Layanan',
                          style: AppTypography.headlineLarge.copyWith(fontSize: 24),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Pilih meja kosong untuk pesanan baru, atau meja terisi untuk mengedit/checkout pesanan draft.',
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.l),
                        Expanded(
                          child: ResponsiveLayout(
                            mobile: _buildGrid(context, tableState.allTables, orderState.activeOrdersMap, crossAxisCount: 2),
                            tablet: _buildGrid(context, tableState.allTables, orderState.activeOrdersMap, crossAxisCount: 4),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildGrid(
    BuildContext context,
    List<TableModel> tables,
    Map<String, dynamic> activeOrdersMap, {
    required int crossAxisCount,
  }) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.m,
        crossAxisSpacing: AppSpacing.m,
        childAspectRatio: 1.1,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        final activeOrder = activeOrdersMap[table.id];
        
        Color getStatusColor() {
          if (table.isOccupied) return AppColors.secondary;
          if (table.isReserved) return AppColors.warning;
          if (table.isMaintenance) return AppColors.error;
          return AppColors.success;
        }

        return InkWell(
          onTap: table.isMaintenance ? null : () => _handleTableSelected(table),
          borderRadius: BorderRadius.circular(16),
          child: AppCard(
            borderSide: BorderSide(
              color: table.isOccupied 
                  ? AppColors.secondary.withOpacity(0.5) 
                  : AppColors.divider,
              width: table.isOccupied ? 2 : 1,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: getStatusColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        table.statusLabel,
                        style: TextStyle(
                          color: getStatusColor(),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'No: ${table.nomor}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  Icons.table_restaurant_rounded,
                  size: 32,
                  color: table.isOccupied ? AppColors.secondary : AppColors.primary,
                ),
                const Spacer(),
                Text(
                  table.nama,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (table.isOccupied && activeOrder != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(activeOrder.grandTotal),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
