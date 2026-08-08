import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/models/table.dart';

class TableActionBottomSheet extends ConsumerWidget {
  final TableModel table;
  final dynamic activeOrder;
  final VoidCallback onPay;
  final VoidCallback onAddBatch;
  final VoidCallback onPrintBill;
  final VoidCallback onFinishCleaning;
  final VoidCallback onMoveTable;

  const TableActionBottomSheet({
    super.key,
    required this.table,
    this.activeOrder,
    required this.onPay,
    required this.onAddBatch,
    required this.onPrintBill,
    required this.onFinishCleaning,
    required this.onMoveTable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // HEADER: Nama Meja + Danger Menu (More Options)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meja ${table.nomor} - ${table.nama}',
                      style: AppTypography.titleMedium.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (activeOrder?.customerName != null &&
                        activeOrder.customerName.toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Atas Nama: ${activeOrder.customerName}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    _buildStatusChip(),
                  ],
                ),
              ),
              // DANGER / DESTRUCTIVE MENU (Terisolasi dari aksi utama)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                tooltip: 'Aksi Lainnya & Manajemen',
                onSelected: (value) {
                  if (value == 'move_table') {
                    onMoveTable();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'move_table',
                    child: Row(
                      children: [
                        Icon(Icons.move_up_rounded, color: AppColors.secondary, size: 20),
                        SizedBox(width: 8),
                        Text('Pindah Meja'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 24),

          // SUMMARY BOX (Jika ada pesanan aktif)
          if (activeOrder != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No. Order: ${activeOrder.nomorOrder ?? "-"}',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Tagihan:',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(activeOrder.grandTotal ?? 0.0),
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // PRIMARY ACTIONS BAR (Bergantung pada state meja)
          ..._buildPrimaryActionButtons(context),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  List<Widget> _buildPrimaryActionButtons(BuildContext context) {
    if (table.isEmpty) {
      return [
        ElevatedButton.icon(
          onPressed: onAddBatch,
          icon: const Icon(Icons.restaurant_menu),
          label: const Text('BUKA PESANAN BARU (DINE-IN)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ];
    } else if (table.needsCleaning) {
      return [
        ElevatedButton.icon(
          onPressed: onFinishCleaning,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('SELESAI DIBERSIHKAN (KOSONGKAN)'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ];
    } else {
      final isBillPrinted = table.isBillPrinted;
      return [
        // Aksi Utama: Bayar
        ElevatedButton.icon(
          onPressed: onPay,
          icon: const Icon(Icons.payment),
          label: const Text('BAYAR SEKARANG'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 10),
        // Row Aksi Pendukung: Tambah Batch & Cetak Tagihan
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  if (isBillPrinted) {
                    _showOverrideConfirmDialog(context, onAddBatch);
                  } else {
                    onAddBatch();
                  }
                },
                icon: Icon(
                  isBillPrinted
                      ? Icons.lock_open_rounded
                      : Icons.add_circle_outline_rounded,
                ),
                label: Text(
                  isBillPrinted
                      ? 'OVERRIDE (+) PESANAN'
                      : 'TAMBAH PESANAN (#N)',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPrintBill,
                icon: const Icon(Icons.print_outlined),
                label: const Text('CETAK TAGIHAN'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ];
    }
  }

  Widget _buildStatusChip() {
    Color color;
    String label = table.statusLabel;
    switch (table.status) {
      case 0:
        color = Colors.grey;
        break;
      case 1:
        color = Colors.orange;
        break;
      case 4:
        color = Colors.blue;
        break;
      case 2:
        color = Colors.green;
        break;
      default:
        color = Colors.orange;
    }

    return Row(
      children: [
        Chip(
          label: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
          backgroundColor: color,
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  void _showOverrideConfirmDialog(BuildContext context, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tagihan Sudah Dicetak'),
        content: const Text(
          'Tagihan meja ini sudah dicetak sebelumnya. Apakah Anda ingin membuka kunci pesanan untuk menambah pesanan batch baru?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Override & Tambah'),
          ),
        ],
      ),
    );
  }

}
