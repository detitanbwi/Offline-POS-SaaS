import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
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

  Future<void> _handleTableSelected(TableModel table, dynamic activeOrder) async {
    if (table.isOccupied || table.isBillPrinted || table.status != 0) {
      AppSnackbar.showWarning(
        context,
        'Meja "${table.nama}" sudah Terisi / Billed. Untuk menambah pesanan atau ubah meja, silakan masuk melalui menu "Manajemen Meja".',
      );
    } else {
      _navigateToPos(table);
    }
  }

  Future<void> _navigateToPos(TableModel table) async {
    final orderNotifier = ref.read(orderNotifierProvider.notifier);
    final cartNotifier = ref.read(cartNotifierProvider.notifier);
    final productState = ref.read(productNotifierProvider);

    orderNotifier.selectTable(table);

    if (table.isOccupied || table.isBillPrinted) {
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
                          child: _buildGrid(context, tableState.allTables, orderState.activeOrdersMap),
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
    Map<String, dynamic> activeOrdersMap,
  ) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = (width / 110).floor();
    if (crossAxisCount < 3) crossAxisCount = 3;
    if (crossAxisCount > 8) crossAxisCount = 8;

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.s,
        crossAxisSpacing: AppSpacing.s,
        childAspectRatio: 0.9,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        final activeOrder = activeOrdersMap[table.id];
        
        Color getStatusColor() {
          if (table.isOccupied) return AppColors.success; // Hijau
          if (table.isBillPrinted) return AppColors.warning; // Kuning
          if (table.isReserved) return AppColors.secondary;
          if (table.isMaintenance) return AppColors.error;
          return Colors.white; // Kosong
        }

        final isFilled = table.isOccupied || table.isBillPrinted;

        return InkWell(
          onTap: table.isMaintenance ? null : () => _handleTableSelected(table, activeOrder),
          borderRadius: BorderRadius.circular(12),
          child: AppCard(
            borderSide: BorderSide(
              color: isFilled 
                  ? getStatusColor()
                  : AppColors.divider,
              width: isFilled ? 1.5 : 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: getStatusColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          table.statusLabel,
                          style: TextStyle(
                            color: table.isEmpty ? AppColors.textPrimary : getStatusColor(),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'No: ${table.nomor}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.table_restaurant_rounded,
                  size: 26,
                  color: isFilled ? getStatusColor() : AppColors.textSecondary,
                ),
                const Spacer(),
                Text(
                  table.nama,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isFilled && activeOrder != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(activeOrder.grandTotal),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: getStatusColor(),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
