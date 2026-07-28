import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
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
import '../../domain/models/order_item.dart';
import '../../../../core/di/providers.dart';
import 'pos_screen.dart';
import 'payment_screen.dart';

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
    if (table.isOccupied || table.isBillPrinted) {
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

  Future<void> _navigateToPayment(TableModel table, dynamic activeOrder) async {
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
      MaterialPageRoute(builder: (_) => const PaymentScreen()),
    ).then((_) {
      ref.read(tableNotifierProvider.notifier).loadTables();
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
    });
  }

  Future<void> _showOccupiedTableBottomSheet(TableModel table, dynamic activeOrder) async {
    final hasDraft = activeOrder != null;
    final repo = ref.read(orderRepositoryProvider);

    List<OrderItemModel> items = [];
    List<Map<String, dynamic>> batches = [];

    if (hasDraft) {
      items = await repo.getOrderItems(activeOrder.id);
      batches = await repo.getPrintBatches(activeOrder.id);
    }

    // Build batch mapping
    final Map<String, int> batchIndexMap = {};
    for (int i = 0; i < batches.length; i++) {
      final bId = batches[i]['id'] as String;
      batchIndexMap[bId] = i + 1;
    }

    // Group items by batch title
    final Map<String, List<OrderItemModel>> groupedItems = {};

    for (var item in items) {
      String batchTitle = 'Batch #1';
      if (item.printBatchId != null && batchIndexMap.containsKey(item.printBatchId)) {
        batchTitle = 'Batch #${batchIndexMap[item.printBatchId]}';
      } else if (item.statusCetak == 0 && batches.isNotEmpty) {
        batchTitle = 'Batch Baru (Belum Kirim Dapur)';
      }

      groupedItems.putIfAbsent(batchTitle, () => []).add(item);
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          padding: const EdgeInsets.all(AppSpacing.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rincian ${table.nama}',
                        style: AppTypography.titleMedium.copyWith(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (activeOrder?.customerName != null && activeOrder.customerName.isNotEmpty)
                        Text(
                          'Atas Nama: ${activeOrder.customerName}',
                          style: AppTypography.bodySmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Status Card
              Container(
                padding: const EdgeInsets.all(12),
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
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasDraft ? 'Status: Belum Dibayar (Draft Active)' : 'Status: Kosong / Lunas',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: hasDraft ? const Color(0xFF78350F) : const Color(0xFF14532D),
                            ),
                          ),
                          if (activeOrder != null) ...[
                            Text('No. Order: ${activeOrder.nomorOrder}', style: const TextStyle(fontSize: 12)),
                            Text(
                              'Total Tagihan: ${CurrencyFormatter.format(activeOrder.grandTotal)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Items List Grouped by Batch
              if (groupedItems.isNotEmpty) ...[
                Text('Rincian Pesanan per Batch:', style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView(
                    children: groupedItems.entries.map((entry) {
                      final batchTitle = entry.key;
                      final batchItemList = entry.value;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withValues(alpha: 0.6),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.soup_kitchen_rounded, size: 16, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    batchTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                                  ),
                                  const Spacer(),
                                    Text(
                                      '${batchItemList.length} Menu',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: 8),
                                    if (batchItemList.first.printBatchId != null)
                                      InkWell(
                                        onTap: () {
                                          Navigator.pop(context);
                                          _showCancelDialog(context, table, activeOrder, batchId: batchItemList.first.printBatchId);
                                        },
                                        child: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.error),
                                      ),
                                  ],
                                ),
                              ),
                            ...batchItemList.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item.qty}x', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.produkNama, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        if (item.catatan != null && item.catatan!.isNotEmpty)
                                          Text('Note: ${item.catatan}', style: const TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic)),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(item.subtotal),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showCancelDialog(context, table, activeOrder, itemId: item.id, itemName: item.produkNama);
                                    },
                                    child: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ] else
                const Expanded(
                  child: Center(
                    child: Text('Belum ada rincian pesanan'),
                  ),
                ),
              const SizedBox(height: 12),
              // Action Buttons
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _navigateToPos(table);
                          },
                          icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                          label: Text(hasDraft ? 'Tambah Menu' : 'Pesan Baru'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      if (hasDraft) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _navigateToPayment(table, activeOrder);
                            },
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            label: const Text('Bayar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasDraft) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _handleMoveTable(context, table, activeOrder);
                            },
                            icon: const Icon(Icons.move_up_rounded, size: 18),
                            label: const Text('Pindah'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _confirmClearTable(table, activeOrder);
                            },
                            icon: const Icon(Icons.cleaning_services_outlined, size: 18, color: AppColors.error),
                            label: const Text('Kosongkan', style: TextStyle(color: AppColors.error, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClearTable(TableModel table, dynamic activeOrder) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kosongkan Meja'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Apakah Anda yakin ingin mengosongkan meja "${table.nama}"?'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Alasan (Wajib)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  AppSnackbar.showWarning(context, 'Alasan harus diisi.');
                  return;
                }
                Navigator.pop(context);
                
                await ref.read(orderNotifierProvider.notifier).clearTableOnly(reason);
                
                if (mounted) {
                  AppSnackbar.showSuccess(context, 'Meja "${table.nama}" berhasil dikosongkan.');
                }
              },
              child: const Text('Ya, Kosongkan'),
            ),
          ],
        );
      },
    );
  }

  void _showCancelDialog(BuildContext context, TableModel table, dynamic activeOrder, {String? batchId, String? itemId, String? itemName}) {
    final reasonController = TextEditingController();
    final pinController = TextEditingController();
    final isBatch = batchId != null;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isBatch ? 'Batalkan Batch' : 'Batalkan $itemName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Alasan Pembatalan:'),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text('Otorisasi Owner (PIN):'),
              const SizedBox(height: 8),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              onPressed: () async {
                final reason = reasonController.text.trim();
                final pin = pinController.text.trim();

                if (reason.isEmpty || pin.length != 6) {
                  AppSnackbar.showWarning(context, 'Harap isi alasan dan PIN (6 digit).');
                  return;
                }

                const salt = 'OfflinePOSSecureSalt_Sprint4_2026';
                var bytes = utf8.encode(pin + salt);
                var digest = sha256.convert(bytes);
                final hashedPin = digest.toString();

                final cashierRepo = ref.read(cashierRepositoryProvider);
                final cashier = await cashierRepo.getCashierByPin(hashedPin);
                
                if (cashier == null || cashier.isOwner != 1) {
                  AppSnackbar.showError(context, 'Otorisasi gagal! PIN salah atau bukan Owner.');
                  return;
                }

                Navigator.pop(context); // Close dialog
                
                if (isBatch) {
                  await ref.read(orderNotifierProvider.notifier).cancelOrderBatch(batchId, reason);
                } else if (itemId != null) {
                  await ref.read(orderNotifierProvider.notifier).cancelOrderItem(itemId, reason);
                }
                
                if (mounted) {
                  AppSnackbar.showSuccess(context, 'Pembatalan berhasil.');
                }
              },
              child: const Text('Batalkan'),
            ),
          ],
        );
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
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: MediaQuery.of(context).size.width > 500 ? 400 : MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pindah Meja - ${sourceTable.nama}', 
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: emptyTables.length,
                    separatorBuilder: (_, _) => const Divider(),
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
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                ),
              ],
            ),
          ),
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
                          color: table.isEmpty ? AppColors.textPrimary : getStatusColor(),
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
