import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/di/providers.dart';
import '../../../product/application/product_notifier.dart';
import '../../application/table_notifier.dart';
import '../../domain/models/table.dart';
import '../../../pos/application/cart_notifier.dart';
import '../../../pos/application/order_notifier.dart';
import '../../../pos/domain/models/order_item.dart';
import '../../../pos/presentation/screens/pos_screen.dart';
import '../../../pos/presentation/screens/payment_screen.dart';

class TableScreen extends ConsumerStatefulWidget {
  const TableScreen({super.key});

  @override
  ConsumerState<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends ConsumerState<TableScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(tableNotifierProvider.notifier).loadTables();
      ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
      ref.read(productNotifierProvider.notifier).loadProducts();
    });
  }

  void _confirmBulkDelete(BuildContext context) {
    AppDialog.show(
      context: context,
      title: 'Hapus Masal Meja',
      message: 'Apakah Anda yakin ingin menghapus ${_selectedIds.length} meja terpilih? Meja yang sedang terisi tidak akan dapat dihapus.',
      confirmText: 'Hapus All',
      isDestructive: true,
      onConfirm: () async {
        final notifier = ref.read(tableNotifierProvider.notifier);
        int successCount = 0;
        List<String> failedTables = [];

        for (final id in _selectedIds) {
          final res = await notifier.deleteTable(id);
          if (res) {
            successCount++;
          } else {
            failedTables.add(id);
          }
        }

        if (!context.mounted) return;
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });

        if (failedTables.isEmpty) {
          AppSnackbar.showSuccess(context, '$successCount meja berhasil dihapus.');
        } else {
          AppSnackbar.showWarning(
            context,
            'Berhasil menghapus $successCount meja. ${failedTables.length} meja gagal dihapus (mungkin sedang terisi pesanan).',
          );
        }
      },
    );
  }

  void _showFormDialog(BuildContext context, {TableModel? table}) {
    final isEdit = table != null;
    final nameController = TextEditingController(text: table?.nama);
    final numberController = TextEditingController(text: table?.nomor);
    int selectedStatus = table?.status ?? 0;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AppDialog(
              title: isEdit ? 'Ubah Data Meja' : 'Tambah Meja Baru',
              confirmText: 'Simpan',
              onConfirm: () async {
                if (formKey.currentState!.validate()) {
                  final name = nameController.text.trim();
                  final number = numberController.text.trim();

                  bool success;
                  if (isEdit) {
                    success = await ref.read(tableNotifierProvider.notifier).updateTable(
                          id: table.id,
                          nama: name,
                          nomor: number,
                          status: selectedStatus,
                        );
                  } else {
                    success = await ref.read(tableNotifierProvider.notifier).createTable(
                          nama: name,
                          nomor: number,
                        );
                  }

                  if (!context.mounted) return;
                  if (success) {
                    Navigator.pop(context);
                    AppSnackbar.showSuccess(
                      context,
                      isEdit ? 'Data meja berhasil diperbarui.' : 'Meja baru berhasil ditambahkan.',
                    );
                  } else {
                    final err = ref.read(tableNotifierProvider).errorMessage;
                    if (err != null) {
                      AppSnackbar.showError(context, err);
                    }
                  }
                }
              },
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: nameController,
                      labelText: 'Nama Meja',
                      hintText: 'Contoh: Meja 01',
                      prefixIcon: Icons.table_restaurant_rounded,
                      validator: (v) => Validators.required(v, 'Nama Meja'),
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: numberController,
                      labelText: 'Nomor Urut Meja',
                      hintText: 'Contoh: 01',
                      prefixIcon: Icons.format_list_numbered_rounded,
                      keyboardType: TextInputType.number,
                      validator: (v) => Validators.required(v, 'Nomor Urut Meja'),
                    ),
                    if (isEdit) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Status Meja',
                          prefixIcon: Icon(Icons.info_outline_rounded),
                        ),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('Kosong')),
                          DropdownMenuItem(value: 1, child: Text('Terisi')),
                          DropdownMenuItem(value: 2, child: Text('Reserved')),
                          DropdownMenuItem(value: 3, child: Text('Maintenance')),
                          DropdownMenuItem(value: 4, child: Text('Bill Dicetak')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedStatus = val);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, TableModel table) {
    AppDialog.show(
      context: context,
      title: 'Hapus Meja',
      message: 'Apakah Anda yakin ingin menghapus "${table.nama}"? Tindakan ini tidak dapat dibatalkan.',
      confirmText: 'Hapus',
      isDestructive: true,
      onConfirm: () async {
        final success = await ref.read(tableNotifierProvider.notifier).deleteTable(table.id);
        if (!context.mounted) return;
        Navigator.pop(context);
        if (success) {
          AppSnackbar.showSuccess(context, 'Meja "${table.nama}" berhasil dihapus.');
        } else {
          final err = ref.read(tableNotifierProvider).errorMessage;
          AppSnackbar.showError(context, err ?? 'Gagal menghapus meja.');
        }
      },
    );
  }

  void _showGenerateDialog(BuildContext context) {
    final countController = TextEditingController(text: '5');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AppDialog(
          title: 'Generate Meja Otomatis',
          confirmText: 'Generate',
          onConfirm: () async {
            if (formKey.currentState!.validate()) {
              final count = int.tryParse(countController.text.trim()) ?? 0;
              if (count <= 0 || count > 50) {
                AppSnackbar.showWarning(context, 'Jumlah meja harus antara 1 dan 50.');
                return;
              }

              final success = await ref.read(tableNotifierProvider.notifier).generateMultipleTables(count);
              if (!context.mounted) return;
              if (success) {
                Navigator.pop(context);
                AppSnackbar.showSuccess(context, 'Berhasil menambahkan $count meja otomatis.');
              } else {
                final err = ref.read(tableNotifierProvider).errorMessage;
                if (err != null) {
                  AppSnackbar.showError(context, err);
                }
              }
            }
          },
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Sistem akan otomatis membuatkan nama & nomor meja secara berurutan (misal: Meja 01, Meja 02, dst).',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: countController,
                  labelText: 'Jumlah Meja yang Ingin Dibuat',
                  hintText: 'Contoh: 10',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.add_moderator_rounded,
                  validator: (v) => Validators.required(v, 'Jumlah Meja'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleTableClick(TableModel table) async {
    final orderState = ref.read(orderNotifierProvider);
    final activeOrder = orderState.activeOrdersMap[table.id];

    if (table.isOccupied || table.isBillPrinted || activeOrder != null) {
      await _showOccupiedTableBottomSheet(table, activeOrder);
    } else {
      _navigateToPos(table, null);
    }
  }

  Future<void> _navigateToPos(TableModel table, dynamic activeOrder) async {
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
    final repo = ref.read(orderRepositoryProvider);

    List<OrderItemModel> items = [];
    List<Map<String, dynamic>> batches = [];

    if (activeOrder != null) {
      items = await repo.getOrderItems(activeOrder.id);
      batches = await repo.getPrintBatches(activeOrder.id);
    }

    final Map<String, int> batchIndexMap = {};
    for (int i = 0; i < batches.length; i++) {
      final bId = batches[i]['id'] as String;
      batchIndexMap[bId] = i + 1;
    }

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
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.9,
          ),
          child: SingleChildScrollView(
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
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Status Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (table.isBillPrinted ? AppColors.warning : AppColors.success).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: (table.isBillPrinted ? AppColors.warning : AppColors.success).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      table.isBillPrinted ? Icons.receipt_rounded : Icons.check_circle_outline_rounded,
                      color: table.isBillPrinted ? AppColors.warning : AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: ${table.statusLabel}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: table.isBillPrinted ? const Color(0xFF78350F) : const Color(0xFF14532D),
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
                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: groupedItems.entries.map((entry) {
                      final batchTitle = entry.key;
                      final batchItemList = entry.value;
                      final hasActiveItemsInBatch = batchItemList.any((i) => !i.isCancelled);

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
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer.withValues(alpha: 0.6),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.soup_kitchen_rounded, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    batchTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${batchItemList.length} Menu',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 8),
                                  if (hasActiveItemsInBatch && batchItemList.first.printBatchId != null)
                                    InkWell(
                                      onTap: () {
                                        Navigator.pop(sheetContext);
                                        _showCancelDialog(context, table, activeOrder, batchId: batchItemList.first.printBatchId);
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(Icons.cancel_outlined, size: 20, color: AppColors.error),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            ...batchItemList.map((item) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item.qty}x',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      decoration: item.isCancelled ? TextDecoration.lineThrough : null,
                                      color: item.isCancelled ? Colors.grey : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.produkNama,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  decoration: item.isCancelled ? TextDecoration.lineThrough : null,
                                                  color: item.isCancelled ? Colors.grey : Colors.black87,
                                                ),
                                              ),
                                            ),
                                            if (item.isCancelled)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade100,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'DIBATALKAN',
                                                  style: TextStyle(fontSize: 9, color: Colors.red.shade800, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (item.catatan != null && item.catatan!.isNotEmpty)
                                          Text(
                                            'Note: ${item.catatan}',
                                            style: const TextStyle(fontSize: 11, color: Colors.orange, fontStyle: FontStyle.italic),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    CurrencyFormatter.format(item.subtotal),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      decoration: item.isCancelled ? TextDecoration.lineThrough : null,
                                      color: item.isCancelled ? Colors.grey : Colors.black87,
                                    ),
                                  ),
                                  if (!item.isCancelled) ...[
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        Navigator.pop(sheetContext);
                                        _showCancelDialog(context, table, activeOrder, itemId: item.id, itemName: item.produkNama);
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Icon(Icons.delete_outline, size: 20, color: AppColors.error),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )),
                          ],
                        ),
                      );
                    }).toList(),
                ),
              ] else
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text('Belum ada rincian pesanan'),
                  ),
                ),
              const SizedBox(height: 12),
              // Action Buttons (4 Action Buttons)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _navigateToPos(table, activeOrder);
                          },
                          icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                          label: Text(activeOrder != null ? 'Tambah Menu' : 'Pesan Baru'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      if (activeOrder != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _navigateToPayment(table, activeOrder);
                            },
                            icon: const Icon(Icons.payments_outlined, size: 18),
                            label: const Text('Bayar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (activeOrder != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _handleMoveTable(context, table, activeOrder);
                            },
                            icon: const Icon(Icons.move_up_rounded, size: 18),
                            label: const Text('Pindah'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(sheetContext);
                              _confirmClearTable(table, activeOrder);
                            },
                            icon: const Icon(Icons.cleaning_services_outlined, size: 18, color: AppColors.error),
                            label: const Text('Kosongkan', style: TextStyle(color: AppColors.error, fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 12),
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

                if (context.mounted) {
                  AppSnackbar.showSuccess(context, 'Meja "${table.nama}" berhasil dikosongkan.');
                  ref.read(tableNotifierProvider.notifier).loadTables();
                  ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
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

                if (!context.mounted) return;

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

                if (context.mounted) {
                  AppSnackbar.showSuccess(context, 'Pembatalan berhasil.');
                  ref.read(tableNotifierProvider.notifier).loadTables();
                  ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
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
                  style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
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

                          final orderRepo = ref.read(orderRepositoryProvider);
                          try {
                            await orderRepo.transferOrderTable(
                              activeOrder.id,
                              sourceTable.id,
                              targetTable.id,
                              targetTable.nama,
                              targetTable.nomor,
                            );

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
    final state = ref.watch(tableNotifierProvider);
    final orderState = ref.watch(orderNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(_isSelectionMode ? '${_selectedIds.length} Meja Terpilih' : 'Manajemen Meja Makan'),
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedIds.clear();
                  });
                },
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Pilih Semua',
              onPressed: () {
                setState(() {
                  if (_selectedIds.length == state.allTables.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds.addAll(state.allTables.map((t) => t.id));
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              tooltip: 'Hapus Terpilih',
              onPressed: _selectedIds.isEmpty ? null : () => _confirmBulkDelete(context),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist_rounded),
              tooltip: 'Mode Pilih Banyak',
              onPressed: () {
                setState(() {
                  _isSelectionMode = true;
                  _selectedIds.clear();
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Tambah Meja',
              onPressed: () => _showFormDialog(context),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: state.isLoading && state.allTables.isEmpty
            ? const AppLoading(message: 'Memuat data meja...')
            : state.allTables.isEmpty
                ? AppEmptyState(
                    title: 'Belum Ada Data Meja',
                    description: 'Silakan tambah meja baru secara manual atau gunakan tombol "Generate Meja" di bawah.',
                    icon: Icons.table_restaurant_rounded,
                    actionText: 'Tambah Meja Baru',
                    onActionPressed: () => _showFormDialog(context),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      await ref.read(tableNotifierProvider.notifier).loadTables();
                      await ref.read(orderNotifierProvider.notifier).loadActiveOrdersMap();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.m),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Daftar Meja (${state.allTables.length})',
                                style: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Ketuk meja terisi untuk kelola pesanan',
                                style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s),
                          Expanded(
                            child: _buildTableGrid(context, state.allTables, orderState.activeOrdersMap),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
      floatingActionButton: state.allTables.isNotEmpty && !_isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: () => _showGenerateDialog(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.playlist_add_rounded),
              label: const Text('Generate Meja'),
            )
          : null,
    );
  }

  Widget _buildTableGrid(BuildContext context, List<TableModel> tables, Map<String, dynamic> activeOrdersMap) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = (width / 130).floor();
    if (crossAxisCount < 2) crossAxisCount = 2;
    if (crossAxisCount > 8) crossAxisCount = 8;

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: AppSpacing.s,
        crossAxisSpacing: AppSpacing.s,
        childAspectRatio: 0.82,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        final activeOrder = activeOrdersMap[table.id];

        Color getStatusColor() {
          if (table.status == 3) return AppColors.error; // Red - Alert / Timeout (#EF9A9A)
          if (table.status == 2) return AppColors.success; // Green - Occupied Prepaid / Done (#A5D6A7)
          if (table.status == 1 || table.status == 4 || table.isOccupied) return AppColors.warning; // Yellow - Occupied Unpaid (#FFF59D)
          return AppColors.textPrimary; // White - Available (#FFFFFF)
        }

        final isFilled = table.isOccupied || table.isBillPrinted || activeOrder != null;
        final isSelected = _selectedIds.contains(table.id);

        return InkWell(
          onTap: _isSelectionMode
              ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedIds.remove(table.id);
                    } else {
                      _selectedIds.add(table.id);
                    }
                  });
                }
              : () => _handleTableClick(table),
          borderRadius: BorderRadius.circular(12),
          child: AppCard(
            color: isFilled
                ? (table.isBillPrinted ? AppColors.warning : AppColors.success).withValues(alpha: 0.05)
                : Colors.white,
            borderSide: BorderSide(
              color: isFilled ? getStatusColor() : AppColors.divider,
              width: isFilled ? 2.0 : 1.0,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isSelectionMode)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedIds.add(table.id);
                                } else {
                                  _selectedIds.remove(table.id);
                                }
                              });
                            },
                          ),
                        ),
                        Text(
                          'No: ${table.nomor}',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: getStatusColor().withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            table.statusLabel,
                            style: TextStyle(
                              color: table.isEmpty ? AppColors.textPrimary : getStatusColor(),
                              fontSize: 9.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'No: ${table.nomor}',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Center(
                  child: Icon(
                    Icons.table_restaurant_rounded,
                    size: 26,
                    color: isFilled ? getStatusColor() : AppColors.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  table.nama,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleMedium.copyWith(fontSize: 13.sp, fontWeight: FontWeight.bold),
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
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                const Divider(height: 4),
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Center(
                      child: Text(
                        table.statusLabel,
                        style: TextStyle(
                          color: getStatusColor(),
                          fontSize: 9.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                        onPressed: () => _showFormDialog(context, table: table),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                        onPressed: () => _showDeleteDialog(context, table),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        tooltip: 'Hapus',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
