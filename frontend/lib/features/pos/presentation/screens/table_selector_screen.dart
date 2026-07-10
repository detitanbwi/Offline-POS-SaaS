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
import '../../../product/application/product_notifier.dart';
import '../../application/cart_notifier.dart';
import '../../application/order_notifier.dart';
import '../../../table/application/table_notifier.dart';
import '../../../table/domain/models/table.dart';
import '../../../../core/di/providers.dart';
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
    if (table.isOccupied) {
      _showOccupiedTableBottomSheet(table, activeOrder);
    } else {
      _navigateToPos(table);
    }
  }

  Future<void> _navigateToPos(TableModel table) async {
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

  void _showOccupiedTableBottomSheet(TableModel table, dynamic activeOrder) {
    final hasDraft = activeOrder != null;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${table.nama} (Nomor: ${table.nomor})',
                      style: AppTypography.titleMedium.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: (hasDraft ? AppColors.warning : AppColors.success).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (hasDraft ? AppColors.warning : AppColors.success).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasDraft ? Icons.hourglass_empty_rounded : Icons.check_circle_outline_rounded,
                        color: hasDraft ? AppColors.warning : AppColors.success,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasDraft ? 'Status: Belum Dibayar (Draft)' : 'Status: Sudah Dibayar (Lunas)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: hasDraft ? const Color(0xFF78350F) : const Color(0xFF14532D),
                              ),
                            ),
                            if (activeOrder != null) ...[
                              const SizedBox(height: 4),
                              Text('No. Order: ${activeOrder.nomorOrder}', style: AppTypography.bodyMedium),
                              Text(
                                'Total Tagihan: ${CurrencyFormatter.format(activeOrder.grandTotal)}',
                                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _navigateToPos(table);
                  },
                  icon: const Icon(Icons.shopping_cart_outlined),
                  label: Text(hasDraft ? 'Lanjutkan Transaksi / Edit' : 'Pesan Baru (Buka POS)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (hasDraft) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleMoveTable(context, table, activeOrder);
                    },
                    icon: const Icon(Icons.move_up_rounded),
                    label: const Text('Pindah Meja'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmClearTable(table, activeOrder);
                  },
                  icon: const Icon(Icons.cleaning_services_outlined, color: AppColors.error),
                  label: const Text('Selesaikan & Kosongkan Meja', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmClearTable(TableModel table, dynamic activeOrder) {
    final hasDraft = activeOrder != null;
    AppDialog.show(
      context: context,
      title: 'Kosongkan Meja',
      message: hasDraft
          ? 'Meja ini memiliki pesanan yang belum dibayar. Apakah Anda yakin ingin membatalkan pesanan dan mengosongkan meja?'
          : 'Apakah Anda yakin ingin menyelesaikan pesanan dan mengosongkan meja "${table.nama}"?',
      confirmText: 'Ya, Kosongkan',
      cancelText: 'Batal',
      isDestructive: true,
      onConfirm: () async {
        if (hasDraft) {
          // If draft exists, cancel order which automatically frees the table
          ref.read(orderNotifierProvider.notifier).selectTable(table);
          await ref.read(orderNotifierProvider.notifier).loadActiveOrderForTable(table.id);
          await ref.read(orderNotifierProvider.notifier).cancelCurrentOrder();
        } else {
          // If no draft (already paid or completed), just update table status to empty (0)
          await ref.read(tableNotifierProvider.notifier).updateStatus(table.id, 0);
        }
        
        // Reload states
        ref.read(tableNotifierProvider.notifier).loadTables();
        ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
        
        if (mounted) {
          AppSnackbar.showSuccess(context, 'Meja "${table.nama}" berhasil dikosongkan.');
        }
      },
    );
  }

  void _handleMoveTable(BuildContext context, TableModel sourceTable, dynamic activeOrder) {
    final tableState = ref.read(tableNotifierProvider);
    final emptyTables = tableState.allTables.where((t) => t.isEmpty).toList();

    if (emptyTables.isEmpty) {
      AppSnackbar.showWarning(context, 'Tidak ada meja kosong yang tersedia untuk dipindahkan.');
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Pindah Meja - ${sourceTable.nama}', 
            style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.separated(
              itemCount: emptyTables.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final targetTable = emptyTables[index];
                return ListTile(
                  leading: const Icon(Icons.table_restaurant_rounded, color: AppColors.primary),
                  title: Text(targetTable.nama),
                  subtitle: Text('Nomor: ${targetTable.nomor}'),
                  onTap: () async {
                    Navigator.pop(context);
                    
                    // Trigger DB transfer
                    final orderRepo = ref.read(orderRepositoryProvider);
                    try {
                      await orderRepo.transferOrderTable(
                        activeOrder.id,
                        sourceTable.id,
                        targetTable.id,
                        targetTable.nama,
                        targetTable.nomor,
                      );
                      
                      // Reload state
                      ref.read(tableNotifierProvider.notifier).loadTables();
                      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
                      
                      if (context.mounted) {
                        AppSnackbar.showSuccess(context, 'Berhasil memindahkan pesanan ke ${targetTable.nama}');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        AppSnackbar.showError(context, 'Gagal memindahkan meja: $e');
                      }
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );
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
          if (table.isOccupied) return AppColors.secondary;
          if (table.isReserved) return AppColors.warning;
          if (table.isMaintenance) return AppColors.error;
          return AppColors.success;
        }

        return InkWell(
          onTap: table.isMaintenance ? null : () => _handleTableSelected(table, activeOrder),
          borderRadius: BorderRadius.circular(12),
          child: AppCard(
            borderSide: BorderSide(
              color: table.isOccupied 
                  ? AppColors.secondary.withValues(alpha: 0.5) 
                  : AppColors.divider,
              width: table.isOccupied ? 1.5 : 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
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
                          color: getStatusColor(),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      'No: ${table.nomor}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  Icons.table_restaurant_rounded,
                  size: 26,
                  color: table.isOccupied ? AppColors.secondary : AppColors.primary,
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
                if (table.isOccupied && activeOrder != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(activeOrder.grandTotal),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.secondary,
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
