// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../../features/pos/domain/models/transaction.dart';
import '../../../printer/application/printer_notifier.dart';
import '../../../printer/domain/models/printer_config.dart';
import '../../../../core/services/printer_service.dart';

class PrinterSettingScreen extends ConsumerStatefulWidget {
  const PrinterSettingScreen({super.key});

  @override
  ConsumerState<PrinterSettingScreen> createState() => _PrinterSettingScreenState();
}

class _PrinterSettingScreenState extends ConsumerState<PrinterSettingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printerNotifierProvider.notifier).loadPrinters();
    });
  }

  Future<void> _handleTestPrint(PrinterConfigModel printer) async {
    try {
      final profile = await CapabilityProfile.load();
      final charsPerLine = printer.effectiveCharsPerLine;
      final generator = Generator(printer.escPosPaperSize, profile);
      List<int> bytes = [];

      final eqLine = '=' * charsPerLine;
      bytes += generator.text(
        'KASIR POS OFFLINE',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'TEST PRINT SUKSES',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.text(
        'Nama Printer : ${printer.name}',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Tipe         : ${printer.isCashier ? "Kasir Utama" : "Dapur/Kitchen"}',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Ukuran Kertas: ${printer.paperSize} mm',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Karakter/Baris: $charsPerLine ${printer.charsPerLine == 0 ? "(Otomatis)" : "(Manual)"}',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Auto Cut     : ${printer.autoCut ? "Aktif" : "Nonaktif"}',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Waktu        : ${DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now())}',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Status       : TERHUBUNG',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(eqLine, styles: const PosStyles(align: PosAlign.center));
      bytes += generator.feed(4);
      if (printer.autoCut) {
        bytes += generator.cut();
      }

      final success = await PrinterService.instance.printBytes(bytes, printer.address);
      if (!mounted) return;
      if (success) {
        AppSnackbar.showSuccess(context, 'Test print terkirim ke printer!');
      } else {
        AppSnackbar.showError(context, 'Gagal mengirim test print ke printer. Periksa koneksi!');
      }
    } catch (e) {
      AppSnackbar.showError(context, 'Error test print: $e');
    }
  }

  Future<void> _showPreviewDialog(PrinterConfigModel printer) async {
    final charsPerLine = printer.effectiveCharsPerLine;
    String previewText = '';

    if (printer.isCashier) {
      final dummyTx = TransactionHeader(
        id: 'dummy-tx-1',
        nomorTransaksi: 'TRX-20260720-001',
        subtotal: 30000,
        taxPercentage: 11,
        taxAmount: 3300,
        grandTotal: 33300,
        nominalBayar: 50000,
        kembalian: 16700,
        paymentMethodId: 'pm-tunai',
        paymentMethodNama: 'Tunai',
        cashierNama: 'Budi Kasir',
        createdAt: DateTime.now(),
      );

      final dummyItems = [
        const TransactionItem(
          id: 'item-1',
          transactionId: 'dummy-tx-1',
          produkId: 'prod-1',
          produkNama: 'Nasi Goreng Spesial',
          produkHarga: 25000,
          qty: 1,
          subtotal: 25000,
          catatan: 'Pedas sedang',
        ),
        const TransactionItem(
          id: 'item-2',
          transactionId: 'dummy-tx-1',
          produkId: 'prod-2',
          produkNama: 'Es Teh Manis',
          produkHarga: 5000,
          qty: 1,
          subtotal: 5000,
        ),
      ];

      previewText = await ReceiptGenerator.formatCashierTextPreview(
        transaction: dummyTx,
        items: dummyItems,
        tableName: 'Meja 03',
        charsPerLine: charsPerLine,
      );
    } else {
      // Kitchen Preview
      final dummyItems = [
        const TransactionItem(
          id: 'item-1',
          transactionId: 'dummy-tx-1',
          produkId: 'prod-1',
          produkNama: 'Nasi Goreng Spesial',
          produkHarga: 25000,
          qty: 2,
          subtotal: 50000,
          catatan: 'Pedas sedang, tanpa timun',
        ),
        const TransactionItem(
          id: 'item-2',
          transactionId: 'dummy-tx-1',
          produkId: 'prod-2',
          produkNama: 'Ayam Bakar Madu',
          produkHarga: 30000,
          qty: 1,
          subtotal: 30000,
          catatan: 'Paha atas',
        ),
      ];

      final eqLine = '=' * charsPerLine;
      final dashLine = '-' * charsPerLine;
      final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

      final buffer = StringBuffer();
      buffer.writeln(eqLine);
      buffer.writeln(ReceiptGenerator.centerText('PESANAN DAPUR', width: charsPerLine));
      buffer.writeln(eqLine);
      buffer.writeln('Meja      : Meja 03');
      buffer.writeln('Batch : #1 (Baru)');
      buffer.writeln('Waktu     : $nowStr');
      buffer.writeln('Kasir     : Budi Kasir');
      buffer.writeln(dashLine);
      buffer.writeln('QTY  ITEM');
      buffer.writeln(dashLine);
      for (var item in dummyItems) {
        buffer.writeln('${item.qty.toString().padLeft(2)}   ${item.produkNama}');
        if (item.catatan != null && item.catatan!.isNotEmpty) {
          buffer.writeln('     - ${item.catatan}');
        }
      }
      buffer.writeln(eqLine);
      previewText = buffer.toString();
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: 420.w,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.l),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Preview Struk (${printer.paperSize}mm)', style: AppTypography.titleMedium),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Text(
                  'Lebar Layout: $charsPerLine Karakter per Baris',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 11.sp),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SingleChildScrollView(
                      child: Center(
                        child: Text(
                          previewText,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: charsPerLine > 36 ? 11.sp : 13.sp,
                            height: 1.25,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'Tutup',
                        type: AppButtonType.outlined,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: 'Test Print',
                        icon: Icons.print_rounded,
                        onPressed: () {
                          Navigator.pop(context);
                          _handleTestPrint(printer);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showScanBottomSheet(BuildContext context) {
    ref.read(printerNotifierProvider.notifier).scanBluetoothDevices();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Consumer(
            builder: (context, ref, child) {
              final state = ref.watch(printerNotifierProvider);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Cari Printer Bluetooth', style: AppTypography.titleLarge),
                      if (state.isScanning)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () => ref.read(printerNotifierProvider.notifier).scanBluetoothDevices(),
                        ),
                    ],
                  ),
                  const Divider(),
                  if (state.errorMessage != null && state.errorMessage!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        state.errorMessage!,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.error, fontSize: 13.sp),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: state.scannedDevices.isEmpty
                        ? AppEmptyState(
                            title: 'Tidak Ada Perangkat Bluetooth',
                            description: state.errorMessage ??
                                'Pastikan Bluetooth HP menyala dan printer termal sudah dipasangkan (paired) di Pengaturan Bluetooth HP Anda.',
                            icon: Icons.bluetooth_disabled_rounded,
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: state.scannedDevices.length,
                            separatorBuilder: (_, _) => const Divider(),
                            itemBuilder: (context, index) {
                              final dev = state.scannedDevices[index];
                              return ListTile(
                                leading: const Icon(Icons.print_rounded, color: AppColors.primary),
                                title: Text(dev.name, style: AppTypography.titleMedium.copyWith(fontSize: 14.sp)),
                                subtitle: Text(dev.address, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12.sp)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () => _setupPrinterConfig(context, dev.name, dev.address, 'cashier'),
                                      child: const Text('Kasir'),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton(
                                      onPressed: () => _setupPrinterConfig(context, dev.name, dev.address, 'kitchen'),
                                      child: const Text('Dapur'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _setupPrinterConfig(BuildContext sheetContext, String name, String address, String type) async {
    Navigator.of(sheetContext).pop();

    if (!mounted) return;

    AppDialog.show(
      context: context,
      title: 'Hubungkan Printer',
      message: 'Hubungkan "$name" sebagai Printer ${type == "cashier" ? "Kasir Utama" : "Dapur"}?',
      confirmText: 'Hubungkan',
      onConfirm: () async {
        Navigator.of(context).pop();
        final success = await ref.read(printerNotifierProvider.notifier).saveAndConnectPrinter(
              name: name,
              address: address,
              type: type,
            );
        if (!mounted) return;
        if (success) {
          AppSnackbar.showSuccess(context, 'Berhasil menghubungkan printer $name');
        } else {
          final err = ref.read(printerNotifierProvider).errorMessage;
          AppSnackbar.showError(context, err ?? 'Gagal menghubungkan printer.');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printerNotifierProvider);

    final cashierPrinter = state.configuredPrinters.firstWhere(
      (p) => p.isCashier,
      orElse: () => PrinterConfigModel(id: '', name: '', address: '', type: '', createdAt: DateTime(2000)),
    );

    final kitchenPrinter = state.configuredPrinters.firstWhere(
      (p) => p.isKitchen,
      orElse: () => PrinterConfigModel(id: '', name: '', address: '', type: '', createdAt: DateTime(2000)),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Pengaturan Thermal Printer'),
      ),
      body: SafeArea(
        child: state.isInitialLoading
            ? const AppLoading(message: 'Memuat data konfigurasi printer...')
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.l),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Konfigurasi Thermal Printer', style: AppTypography.headlineLarge.copyWith(fontSize: 24.sp)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Atur printer Bluetooth untuk kasir dan dapur. Pilih lebar kertas (58mm/80mm) dan jumlah karakter per baris yang sesuai.',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.l),
                    
                    _buildPrinterRoleCard(
                      title: 'Printer Kasir Utama (Struk)',
                      description: 'Mencetak struk belanja transaksi pembayaran kasir.',
                      printer: cashierPrinter.id.isEmpty ? null : cashierPrinter,
                      type: 'cashier',
                    ),
                    const SizedBox(height: 16),
                    
                    _buildPrinterRoleCard(
                      title: 'Printer Dapur (Kitchen Ticket)',
                      description: 'Mencetak rincian pesanan (KOT) untuk juru masak.',
                      printer: kitchenPrinter.id.isEmpty ? null : kitchenPrinter,
                      type: 'kitchen',
                    ),
                    const SizedBox(height: 24),
                    
                    AppButton(
                      text: 'Cari & Sambungkan Printer',
                      icon: Icons.bluetooth_searching_rounded,
                      onPressed: () => _showScanBottomSheet(context),
                      width: double.infinity,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildPrinterRoleCard({
    required String title,
    required String description,
    required PrinterConfigModel? printer,
    required String type,
  }) {
    final state = ref.watch(printerNotifierProvider);
    final isConfigured = printer != null;
    final isLoadingThisCard = state.isLoading && state.loadingType == type;

    return AppCard(
      borderSide: const BorderSide(color: AppColors.divider),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(fontSize: 16.sp),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isConfigured && printer.isConnected 
                      ? AppColors.success 
                      : (isConfigured ? AppColors.info : AppColors.disabled)).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isConfigured && printer.isConnected 
                      ? 'Terhubung' 
                      : (isConfigured ? 'Siap' : 'Terputus'),
                  style: TextStyle(
                    color: isConfigured && printer.isConnected 
                        ? AppColors.success 
                        : (isConfigured ? AppColors.info : AppColors.disabled),
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(description, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12.sp)),
          const Divider(height: 24),
          if (isConfigured) ...[
            Row(
              children: [
                const Icon(Icons.bluetooth_connected_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(printer.name, style: AppTypography.titleMedium.copyWith(fontSize: 14.sp)),
                      Text(printer.address, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 11.sp)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // -----------------------------------------------------------------
            // SETTINGS: Paper Size, Characters per Line, Auto Cut, Density
            // -----------------------------------------------------------------
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ukuran Kertas', style: AppTypography.titleMedium.copyWith(fontSize: 13.sp)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<int>(
                          title: Text('58 mm', style: TextStyle(fontSize: 13.sp)),
                          subtitle: Text('Def: 32 Karakter', style: TextStyle(fontSize: 11.sp)),
                          value: 58,
                          groupValue: printer.paperSize,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(printerNotifierProvider.notifier).updatePrinterSettings(
                                id: printer.id,
                                paperSize: val,
                              );
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<int>(
                          title: Text('80 mm', style: TextStyle(fontSize: 13.sp)),
                          subtitle: Text('Def: 48 Karakter', style: TextStyle(fontSize: 11.sp)),
                          value: 80,
                          groupValue: printer.paperSize,
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(printerNotifierProvider.notifier).updatePrinterSettings(
                                id: printer.id,
                                paperSize: val,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Jumlah Karakter per Baris', style: AppTypography.titleMedium.copyWith(fontSize: 12.sp)),
                            Text('Ditentukan oleh tipe/font printer', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
                          ],
                        ),
                      ),
                      DropdownButton<int>(
                        value: printer.charsPerLine,
                        style: AppTypography.bodyMedium.copyWith(fontSize: 12.sp),
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                            value: 0,
                            child: Text('Otomatis (${printer.paperSize == 80 ? "48" : "32"})'),
                          ),
                          const DropdownMenuItem(value: 28, child: Text('28 Karakter')),
                          const DropdownMenuItem(value: 30, child: Text('30 Karakter')),
                          const DropdownMenuItem(value: 32, child: Text('32 Karakter (58mm)')),
                          const DropdownMenuItem(value: 42, child: Text('42 Karakter')),
                          const DropdownMenuItem(value: 48, child: Text('48 Karakter (80mm)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(printerNotifierProvider.notifier).updatePrinterSettings(
                              id: printer.id,
                              charsPerLine: val,
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  SwitchListTile(
                    title: Text('Auto Cut (Potong Kertas Otomatis)', style: AppTypography.titleMedium.copyWith(fontSize: 12.sp)),
                    subtitle: Text('Kirim perintah pemotong pisau otomatis setelah mencetak', style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 10.sp)),
                    value: printer.autoCut,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) {
                      ref.read(printerNotifierProvider.notifier).updatePrinterSettings(
                        id: printer.id,
                        autoCut: val,
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (isLoadingThisCard)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.remove_red_eye_rounded, size: 14),
                    label: Text('Preview', style: TextStyle(fontSize: 12.sp)),
                    onPressed: () => _showPreviewDialog(printer),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print_rounded, size: 14),
                    label: Text('Test Print', style: TextStyle(fontSize: 12.sp)),
                    onPressed: () => _handleTestPrint(printer),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                  ),
                  if (type == 'cashier')
                    OutlinedButton.icon(
                      icon: const Icon(Icons.point_of_sale_rounded, size: 14, color: AppColors.secondary),
                      label: Text('Buka Drawer', style: TextStyle(color: AppColors.secondary, fontSize: 12.sp)),
                      onPressed: () async {
                        final success = await ref.read(printerNotifierProvider.notifier).openCashDrawer(targetAddress: printer.address);
                        if (mounted) {
                          if (success) {
                            AppSnackbar.showSuccess(context, 'Perintah pembuka laci kasir berhasil dikirim.');
                          } else {
                            AppSnackbar.showWarning(context, 'Gagal membuka laci kasir. Pastikan printer kasir terhubung.');
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        side: const BorderSide(color: AppColors.secondary),
                      ),
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.link_off_rounded, size: 14, color: AppColors.error),
                    label: Text('Putuskan', style: TextStyle(color: AppColors.error, fontSize: 12.sp)),
                    onPressed: () async {
                      final success = await ref.read(printerNotifierProvider.notifier).deletePrinter(printer.id);
                      if (success && mounted) {
                        AppSnackbar.showSuccess(context, 'Printer berhasil diputuskan.');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ],
              ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: isLoadingThisCard
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'Belum ada printer terkonfigurasi.',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.disabled, fontStyle: FontStyle.italic),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
