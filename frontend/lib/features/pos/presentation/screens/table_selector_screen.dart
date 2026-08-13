import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
import 'cashier_screen.dart';

class TableSelectorScreen extends ConsumerStatefulWidget {
  const TableSelectorScreen({super.key});

  @override
  ConsumerState<TableSelectorScreen> createState() => _TableSelectorScreenState();
}

class _TableSelectorScreenState extends ConsumerState<TableSelectorScreen> {
  String? _selectedTableId;
  TableModel? _selectedTable;

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
    setState(() {
      _selectedTableId = table.id;
      _selectedTable = table;
    });

    if (table.isOccupied || table.isBillPrinted || table.status != 0) {
      AppSnackbar.showWarning(
        context,
        'Meja "${table.nama}" sudah Terisi / Billed. Klik "Lanjutkan" untuk membuka detail pesanan.',
      );
    }
  }

  Future<void> _navigateToCashier(TableModel table) async {
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
      MaterialPageRoute(builder: (_) => const CashierScreen()),
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
        title: Text('Pilih Meja Restoran'),
      ),
      bottomNavigationBar: _selectedTable != null
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Meja Terpilih:',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                          ),
                          Text(
                            _selectedTable!.nama,
                            style: AppTypography.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: Text(
                        'Lanjutkan',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
                      ),
                      label: Icon(Icons.arrow_forward_rounded),
                      onPressed: () => _navigateToCashier(_selectedTable!),
                    ),
                  ],
                ),
              ),
            )
          : null,
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
                          'Pilih Meja',
                          style: AppTypography.headlineLarge.copyWith(fontSize: 24.sp),
                        ),
                        SizedBox(height: AppSpacing.l),
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

        final isOccupied = table.isOccupied || table.isBillPrinted;
        final isSelected = _selectedTableId == table.id;

        // Styling specs:
        // Occupied: Solid Green Block
        // Selected: Orange Outlined
        // Available: Grey Outlined (unfilled)
        Color cardBgColor;
        BorderSide borderSide;
        Color textColor;
        Color iconColor;

        if (isOccupied) {
          cardBgColor = AppColors.success;
          borderSide = BorderSide.none;
          textColor = Colors.white;
          iconColor = Colors.white;
        } else if (isSelected) {
          cardBgColor = AppColors.secondaryContainer.withValues(alpha: 0.2);
          borderSide = const BorderSide(color: AppColors.secondary, width: 2.5);
          textColor = AppColors.secondary;
          iconColor = AppColors.secondary;
        } else {
          cardBgColor = AppColors.surface;
          borderSide = const BorderSide(color: AppColors.divider, width: 1.5);
          textColor = AppColors.textPrimary;
          iconColor = AppColors.textSecondary;
        }

        return InkWell(
          onTap: table.isMaintenance ? null : () => _handleTableSelected(table, activeOrder),
          borderRadius: BorderRadius.circular(12),
          child: AppCard(
            color: cardBgColor,
            borderSide: borderSide,
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
                          color: isOccupied ? Colors.white.withValues(alpha: 0.25) : iconColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          table.statusLabel,
                          style: TextStyle(
                            color: isOccupied ? Colors.white : textColor,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'No: ${table.nomor}',
                        style: TextStyle(
                          color: isOccupied ? Colors.white70 : AppColors.textSecondary,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.table_restaurant_rounded,
                  size: 28,
                  color: iconColor,
                ),
                const Spacer(),
                Text(
                  table.nama,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: isOccupied ? Colors.white : AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isOccupied && activeOrder != null) ...[
                  SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(activeOrder.grandTotal),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.sp,
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
