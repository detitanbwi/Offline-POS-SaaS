import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/di/providers.dart';
import '../../application/transaction_history_notifier.dart';
import '../../../pos/domain/models/transaction.dart';


class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transactionHistoryNotifierProvider.notifier).loadTransactions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showReceiptDetail(BuildContext context, TransactionHeader tx) async {
    // Show loading dialog while fetching items
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final items = await ref.read(transactionHistoryNotifierProvider.notifier).getItems(tx.id);
    final storage = ref.read(secureStorageServiceProvider);
    final storeName = await storage.getStoreName() ?? 'Toko Kasir Offline';
    final storeAddress = await storage.getStoreAddress() ?? 'Jl. Bisnis Commercial POS, Indonesia';
    final storePhone = await storage.getStorePhone();

    if (!context.mounted) return;
    Navigator.pop(context); // Dismiss loading dialog

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(AppSpacing.l),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Struk Transaksi', style: AppTypography.titleLarge),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 12),
                // Mock Print Preview Layout
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.divider),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Column(
                          children: [
                            Text(storeName,
                                style: AppTypography.titleMedium.copyWith(fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(storeAddress, style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                            if (storePhone != null && storePhone.isNotEmpty) ...[
                              Text('Telp: $storePhone', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildReceiptTextRow('No. Transaksi', tx.nomorTransaksi),
                      _buildReceiptTextRow('Waktu', DateFormat('yyyy-MM-dd HH:mm').format(tx.createdAt)),
                      _buildReceiptTextRow('Kasir', tx.cashierNama ?? 'Pemilik'),
                      _buildReceiptTextRow('Status', tx.status.toUpperCase()),
                      _buildDottedLine(),
                      // List of items
                      ...items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(item.produkNama, style: AppTypography.titleMedium.copyWith(fontSize: 13)),
                                  Text(
                                    CurrencyFormatter.format(item.subtotal),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                              Text(
                                '${item.qty} x ${CurrencyFormatter.format(item.produkHarga)}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              if (item.catatan != null && item.catatan!.isNotEmpty) ...[
                                Text(
                                  'Catatan: ${item.catatan}',
                                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.secondary),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      _buildDottedLine(),
                      _buildReceiptTextRow('Subtotal', CurrencyFormatter.format(tx.subtotal)),
                      if (tx.taxPercentage > 0) ...[
                        _buildReceiptTextRow('Pajak (PPN ${tx.taxPercentage.toStringAsFixed(0)}%)', CurrencyFormatter.format(tx.taxAmount)),
                      ],
                      _buildReceiptTextRow('Total Bayar', CurrencyFormatter.format(tx.grandTotal), isBold: true),
                      _buildReceiptTextRow('Metode Bayar', tx.paymentMethodNama),
                      _buildReceiptTextRow('Jumlah Bayar', CurrencyFormatter.format(tx.nominalBayar)),
                      _buildReceiptTextRow('Kembalian', CurrencyFormatter.format(tx.kembalian), isBold: true),
                      _buildDottedLine(),
                      const Center(
                        child: Text(
                          'Terima kasih atas kunjungan Anda',
                          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (tx.status == 'completed') ...[
                  AppButton(
                    text: 'Batalkan Transaksi (Void)',
                    type: AppButtonType.destructive,
                    onPressed: () {
                      Navigator.pop(context);
                      _handleVoidTransaction(context, tx);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleVoidTransaction(BuildContext context, TransactionHeader tx) {
    final pinController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Otorisasi Pembatalan (Void)', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Masukkan PIN Master Pemilik untuk mengotorisasi pembatalan transaksi ini.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: AppSpacing.m),
                AppTextField(
                  controller: pinController,
                  labelText: 'PIN Master Pemilik',
                  hintText: 'Masukkan 6 digit PIN Master',
                  prefixIcon: Icons.lock_rounded,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  validator: (val) {
                    if (val == null || val.length != 6) {
                      return 'PIN harus tepat 6 digit';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final enteredPin = pinController.text;
                  const salt = 'OfflinePOSSecureSalt_Sprint4_2026';
                  final bytesBytes = utf8.encode(enteredPin + salt);
                  final enteredHash = sha256.convert(bytesBytes).toString();

                  final storage = ref.read(secureStorageServiceProvider);
                  final savedHashedPin = await storage.getLocalPIN();

                  if (!context.mounted) return;
                  Navigator.pop(context); // Close dialog

                  if (enteredHash == savedHashedPin) {
                    final notifier = ref.read(transactionHistoryNotifierProvider.notifier);
                    final success = await notifier.voidTransaction(tx.id);
                    
                    if (!context.mounted) return;
                    if (success) {
                      AppSnackbar.showSuccess(context, 'Transaksi ${tx.nomorTransaksi} berhasil dibatalkan (Void). Stok barang dikembalikan.');
                    } else {
                      final state = ref.read(transactionHistoryNotifierProvider);
                      AppSnackbar.showError(context, state.errorMessage ?? 'Gagal membatalkan transaksi.');
                    }
                  } else {
                    AppSnackbar.showError(context, 'Otorisasi gagal! PIN Master Pemilik salah.');
                  }
                }
              },
              child: const Text('Otorisasikan'),
            ),
          ],
        );
      },
    );
  }


  Widget _buildReceiptTextRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDottedLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: List.generate(
          150 ~/ 3,
          (index) => Expanded(
            child: Container(
              color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade400,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionHistoryNotifierProvider);
    final notifier = ref.read(transactionHistoryNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Riwayat Transaksi'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.m),
              child: AppTextField(
                controller: _searchController,
                labelText: 'Cari Struk Transaksi',
                prefixIcon: Icons.search,
                onChanged: (val) => notifier.setSearchQuery(val),
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: state.isLoading
                  ? const AppLoading(message: 'Memuat riwayat transaksi...')
                  : state.filteredTransactions.isEmpty
                      ? AppEmptyState(
                          title: 'Riwayat Transaksi Kosong',
                          description: _searchController.text.isNotEmpty
                              ? 'Tidak ada struk transaksi yang cocok.'
                              : 'Belum ada transaksi tersimpan.',
                          icon: Icons.history_toggle_off_rounded,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.m),
                          itemCount: state.filteredTransactions.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final tx = state.filteredTransactions[index];
                            final timeStr = DateFormat('yyyy-MM-dd HH:mm').format(tx.createdAt);
                            
                            return AppCard(
                              onTap: () => _showReceiptDetail(context, tx),
                              padding: const EdgeInsets.all(16),
                              borderSide: const BorderSide(color: AppColors.divider),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.receipt_long_rounded,
                                      color: AppColors.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          tx.nomorTransaksi,
                                          style: AppTypography.titleMedium.copyWith(fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Pembayaran: ${tx.paymentMethodNama} • $timeStr',
                                          style: AppTypography.bodyMedium.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(tx.grandTotal),
                                    style: AppTypography.titleMedium.copyWith(
                                      color: AppColors.primary,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
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
