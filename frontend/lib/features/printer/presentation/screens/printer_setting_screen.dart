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
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/utils/receipt_generator.dart';
import '../../../../features/pos/domain/models/transaction.dart';
import '../../../../features/pos/domain/models/order.dart';
import '../../../../features/pos/domain/models/order_item.dart';
import '../../../../features/category/application/category_notifier.dart';
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
      ref.read(categoryNotifierProvider.notifier).loadCategories();
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
        'Label        : ${printer.displayName}',
        styles: const PosStyles(align: PosAlign.left, bold: true),
      );
      bytes += generator.text(
        'Nama Device  : ${printer.name}',
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
        AppSnackbar.showSuccess(context, 'Test print terkirim ke printer "${printer.displayName}"!');
      } else {
        AppSnackbar.showError(context, 'Gagal mengirim test print ke printer. Periksa koneksi Bluetooth!');
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
      // Kitchen Preview with OrderModel
      final dummyOrder = OrderModel(
        id: 'dummy-order-1',
        nomorOrder: 'ORD-001',
        tableNama: 'Meja 03',
        customerName: 'Pelanggan 1',
        subtotal: 60000,
        taxAmount: 0,
        grandTotal: 60000,
        cashierNama: 'Budi Kasir',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final dummyItems = [
        const OrderItemModel(
          id: 'item-1',
          orderId: 'dummy-order-1',
          produkId: 'prod-1',
          produkNama: 'Nasi Goreng Spesial',
          produkHarga: 25000,
          qty: 2,
          subtotal: 50000,
          catatan: 'Pedas sedang, tanpa timun',
        ),
        const OrderItemModel(
          id: 'item-2',
          orderId: 'dummy-order-1',
          produkId: 'prod-2',
          produkNama: 'Es Teh Manis',
          produkHarga: 5000,
          qty: 2,
          subtotal: 10000,
        ),
      ];

      previewText = await ReceiptGenerator.formatKitchenTextPreview(
        order: dummyOrder,
        itemsToPrint: dummyItems,
        waveInfo: '#1 (BARU)',
        cashierNama: 'Budi Kasir',
        charsPerLine: charsPerLine,
      );
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Row(
          children: [
            Icon(printer.isCashier ? Icons.receipt_long_rounded : Icons.soup_kitchen_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Preview ${printer.displayName} (${printer.paperSize}mm)',
                style: AppTypography.titleMedium.copyWith(fontSize: 15.sp),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                previewText,
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: printer.paperSize == 80 ? 11.5.sp : 10.5.sp,
                  height: 1.25,
                  letterSpacing: 0.5,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  void _showScanBottomSheet(BuildContext context, {String initialType = 'cashier'}) {
    ref.read(printerNotifierProvider.notifier).scanBluetoothDevices();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: SafeArea(
          child: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(printerNotifierProvider);

              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pilih Perangkat Bluetooth', style: AppTypography.titleLarge.copyWith(fontSize: 18.sp)),
                            const SizedBox(height: 2),
                            Text('Printer harus sudah dipasangkan (paired) di HP', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                        if (state.isScanning)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                            onPressed: () => ref.read(printerNotifierProvider.notifier).scanBluetoothDevices(),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: state.scannedDevices.isEmpty
                        ? AppEmptyState(
                            title: 'Tidak Ada Perangkat Bluetooth',
                            description: state.errorMessage ??
                                'Pastikan Bluetooth HP menyala dan printer termal sudah dipasangkan (paired) di Pengaturan Bluetooth HP Anda.',
                            icon: Icons.bluetooth_disabled_rounded,
                          )
                        : ListView.separated(
                            itemCount: state.scannedDevices.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final dev = state.scannedDevices[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primaryContainer,
                                  child: const Icon(Icons.print_rounded, color: AppColors.primary, size: 20),
                                ),
                                title: Text(dev.name, style: AppTypography.titleMedium.copyWith(fontSize: 14.sp)),
                                subtitle: Text(dev.address, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12.sp)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                                      ),
                                      onPressed: () {
                                        Navigator.of(bottomSheetContext).pop();
                                        _showConfigDialog(
                                          deviceName: dev.name,
                                          deviceAddress: dev.address,
                                          initialType: initialType,
                                        );
                                      },
                                      child: const Text('Pilih'),
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

  void _showConfigDialog({
    PrinterConfigModel? existingPrinter,
    String? deviceName,
    String? deviceAddress,
    String initialType = 'kitchen',
  }) {
    final isEditing = existingPrinter != null;
    final name = isEditing ? existingPrinter.name : (deviceName ?? '');
    final address = isEditing ? existingPrinter.address : (deviceAddress ?? '');

    String selectedType = isEditing ? existingPrinter.type : initialType;
    final labelCtrl = TextEditingController(text: isEditing ? (existingPrinter.label ?? '') : '');
    int selectedPaperSize = isEditing ? existingPrinter.paperSize : 58;
    int selectedCharsPerLine = isEditing ? existingPrinter.charsPerLine : 0;
    bool autoCut = isEditing ? existingPrinter.autoCut : false;
    List<String> selectedCategoryIds = isEditing ? List.from(existingPrinter.categoryIds) : [];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final categories = ref.watch(categoryNotifierProvider).allCategories;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
            title: Row(
              children: [
                Icon(
                  selectedType == 'cashier' ? Icons.point_of_sale_rounded : Icons.soup_kitchen_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isEditing ? 'Ubah Konfigurasi Printer' : 'Tambah Printer Baru',
                  style: AppTypography.titleMedium.copyWith(fontSize: 16.sp),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Device info banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bluetooth_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: AppTypography.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                                Text(address, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 10.5.sp)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Role Type Selector
                    Text('Tipe Peran Printer', style: AppTypography.titleSmall.copyWith(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: isEditing && existingPrinter.isCashier ? null : () => setDialogState(() => selectedType = 'cashier'),
                            borderRadius: BorderRadius.circular(8.r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: selectedType == 'cashier' ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                                border: Border.all(
                                  color: selectedType == 'cashier' ? AppColors.primary : AppColors.divider,
                                  width: selectedType == 'cashier' ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.point_of_sale_rounded, size: 16, color: selectedType == 'cashier' ? AppColors.primary : AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Kasir Utama',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: selectedType == 'cashier' ? FontWeight.bold : FontWeight.normal,
                                      color: selectedType == 'cashier' ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: isEditing && existingPrinter.isCashier ? null : () => setDialogState(() => selectedType = 'kitchen'),
                            borderRadius: BorderRadius.circular(8.r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                color: selectedType == 'kitchen' ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                                border: Border.all(
                                  color: selectedType == 'kitchen' ? AppColors.primary : AppColors.divider,
                                  width: selectedType == 'kitchen' ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.soup_kitchen_rounded, size: 16, color: selectedType == 'kitchen' ? AppColors.primary : AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Dapur (Kitchen)',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: selectedType == 'kitchen' ? FontWeight.bold : FontWeight.normal,
                                      color: selectedType == 'kitchen' ? AppColors.primary : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Custom Label input
                    Text('Label / Nama Khusus Printer', style: AppTypography.titleSmall.copyWith(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    AppTextField(
                      controller: labelCtrl,
                      labelText: 'Label Printer',
                      hintText: selectedType == 'cashier' ? 'Misal: Kasir Depan' : 'Misal: Dapur Makanan, Bar Minuman, Dapur Lt 2',
                      maxLength: 40,
                    ),
                    const SizedBox(height: 10),

                    // Paper Size & Chars per line
                    Text('Ukuran Kertas', style: AppTypography.titleSmall.copyWith(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<int>(
                            title: Text('58 mm', style: TextStyle(fontSize: 12.sp)),
                            value: 58,
                            groupValue: selectedPaperSize,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: (val) => setDialogState(() => selectedPaperSize = val ?? 58),
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<int>(
                            title: Text('80 mm', style: TextStyle(fontSize: 12.sp)),
                            value: 80,
                            groupValue: selectedPaperSize,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            onChanged: (val) => setDialogState(() => selectedPaperSize = val ?? 80),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: Text('Karakter / Baris:', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
                        ),
                        DropdownButton<int>(
                          value: selectedCharsPerLine,
                          style: AppTypography.bodyMedium.copyWith(fontSize: 12.sp),
                          underline: const SizedBox(),
                          items: [
                            DropdownMenuItem(
                              value: 0,
                              child: Text('Otomatis (${selectedPaperSize == 80 ? "48" : "32"})'),
                            ),
                            const DropdownMenuItem(value: 28, child: Text('28 Karakter')),
                            const DropdownMenuItem(value: 30, child: Text('30 Karakter')),
                            const DropdownMenuItem(value: 32, child: Text('32 Karakter (58mm)')),
                            const DropdownMenuItem(value: 42, child: Text('42 Karakter')),
                            const DropdownMenuItem(value: 48, child: Text('48 Karakter (80mm)')),
                          ],
                          onChanged: (val) => setDialogState(() => selectedCharsPerLine = val ?? 0),
                        ),
                      ],
                    ),

                    SwitchListTile(
                      title: Text('Auto Cut (Potong Kertas)', style: TextStyle(fontSize: 12.sp)),
                      value: autoCut,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) => setDialogState(() => autoCut = val),
                    ),

                    // Category Mapping for Kitchen Printers
                    if (selectedType == 'kitchen') ...[
                      const Divider(height: 20),
                      Text(
                        'Kategori Produk yang Dicetak:',
                        style: AppTypography.titleSmall.copyWith(fontSize: 12.sp, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Jika tidak ada yang dipilih, printer ini akan mencetak semua kategori produk.',
                        style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      if (categories.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text('Belum ada kategori terdaftar.', style: TextStyle(fontSize: 11.sp, fontStyle: FontStyle.italic)),
                        )
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: categories.map((cat) {
                            final isSelected = selectedCategoryIds.contains(cat.id);
                            return FilterChip(
                              label: Text(cat.nama, style: TextStyle(fontSize: 11.sp, color: isSelected ? Colors.white : AppColors.textPrimary)),
                              selected: isSelected,
                              selectedColor: AppColors.primary,
                              checkmarkColor: Colors.white,
                              backgroundColor: AppColors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6.r),
                                side: BorderSide(color: isSelected ? AppColors.primary : AppColors.divider),
                              ),
                              onSelected: (bool selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedCategoryIds.add(cat.id);
                                  } else {
                                    selectedCategoryIds.remove(cat.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
                onPressed: () async {
                  Navigator.of(dialogCtx).pop();
                  final labelText = labelCtrl.text.trim();

                  final success = await ref.read(printerNotifierProvider.notifier).saveAndConnectPrinter(
                    id: existingPrinter?.id,
                    name: name,
                    label: labelText.isNotEmpty ? labelText : null,
                    address: address,
                    type: selectedType,
                    paperSize: selectedPaperSize,
                    charsPerLine: selectedCharsPerLine,
                    autoCut: autoCut,
                    categoryIds: selectedCategoryIds,
                  );

                  if (!mounted) return;
                  if (success) {
                    AppSnackbar.showSuccess(context, 'Berhasil menyimpan printer ${labelText.isNotEmpty ? labelText : name}');
                  } else {
                    final err = ref.read(printerNotifierProvider).errorMessage;
                    AppSnackbar.showError(context, err ?? 'Gagal menyimpan printer.');
                  }
                },
                child: Text(isEditing ? 'Simpan Perubahan' : 'Hubungkan'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printerNotifierProvider);
    final categories = ref.watch(categoryNotifierProvider).allCategories;

    final cashierPrinter = state.cashierPrinter;
    final kitchenPrinters = state.kitchenPrinters;

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
                    Text('Konfigurasi Thermal Printer', style: AppTypography.headlineLarge.copyWith(fontSize: 22.sp)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Atur printer Bluetooth kasir dan printer dapur (mendukung lebih dari satu printer dapur dengan label kustom dan routing kategori menu).',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12.sp),
                    ),
                    const SizedBox(height: AppSpacing.l),

                    // 1. CASHIER PRINTER SECTION
                    _buildCashierPrinterCard(cashierPrinter),
                    const SizedBox(height: 24),

                    // 2. MULTI KITCHEN PRINTER SECTION
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Printer Dapur',
                                  style: AppTypography.titleMedium.copyWith(fontSize: 16.sp, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  '${kitchenPrinters.length} Printer',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (kitchenPrinters.isNotEmpty)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: Text('Tambah', style: TextStyle(fontSize: 12.sp)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              side: const BorderSide(color: AppColors.primary),
                            ),
                            onPressed: () => _showScanBottomSheet(context, initialType: 'kitchen'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (kitchenPrinters.isEmpty)
                      AppCard(
                        borderSide: const BorderSide(color: AppColors.divider),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            Icon(Icons.soup_kitchen_outlined, size: 36.sp, color: AppColors.textSecondary.withValues(alpha: 0.5)),
                            const SizedBox(height: 8),
                            Text(
                              'Belum ada Printer Dapur terdaftar',
                              style: AppTypography.titleMedium.copyWith(fontSize: 14.sp),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Anda dapat menghubungkan beberapa printer untuk memisahkan pesanan (misal: Dapur Makanan, Bar Minuman).',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            AppButton(
                              text: 'Hubungkan Printer Dapur',
                              icon: Icons.bluetooth_searching_rounded,
                              onPressed: () => _showScanBottomSheet(context, initialType: 'kitchen'),
                            ),
                          ],
                        ),
                      )
                    else
                      ...kitchenPrinters.map((printer) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildKitchenPrinterCard(printer, categories),
                          )),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCashierPrinterCard(PrinterConfigModel? printer) {
    final state = ref.watch(printerNotifierProvider);
    final isConfigured = printer != null;
    final isLoadingThisCard = state.isLoading && state.loadingType == 'cashier';

    return AppCard(
      borderSide: const BorderSide(color: AppColors.divider),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Printer Kasir Utama (Struk)',
                    style: AppTypography.titleMedium.copyWith(fontSize: 15.sp, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (isConfigured && printer.isConnected
                          ? AppColors.success
                          : (isConfigured ? AppColors.info : AppColors.disabled))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isConfigured && printer.isConnected
                      ? 'Terhubung'
                      : (isConfigured ? 'Tersimpan' : 'Belum Diatur'),
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
          Text(
            'Mencetak struk transaksi pembayaran kasir dan mengirim sinyal drawer kick.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const Divider(height: 20),

          if (isConfigured) ...[
            Row(
              children: [
                const Icon(Icons.bluetooth_connected_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(printer.displayName, style: AppTypography.titleMedium.copyWith(fontSize: 14.sp, fontWeight: FontWeight.bold)),
                      if (printer.label != null && printer.label!.isNotEmpty)
                        Text('Device: ${printer.name} (${printer.address})', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 10.5.sp))
                      else
                        Text(printer.address, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.sp)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                  tooltip: 'Ubah Pengaturan',
                  onPressed: () => _showConfigDialog(existingPrinter: printer),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text('${printer.paperSize} mm (${printer.effectiveCharsPerLine} Char)', style: TextStyle(fontSize: 10.5.sp)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.divider),
                ),
                if (printer.autoCut)
                  Chip(
                    label: Text('Auto Cut', style: TextStyle(fontSize: 10.5.sp, color: AppColors.primary)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.3),
                    side: const BorderSide(color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoadingThisCard)
              const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            else
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.remove_red_eye_rounded, size: 14),
                    label: Text('Preview', style: TextStyle(fontSize: 11.5.sp)),
                    onPressed: () => _showPreviewDialog(printer),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print_rounded, size: 14),
                    label: Text('Test Print', style: TextStyle(fontSize: 11.5.sp)),
                    onPressed: () => _handleTestPrint(printer),
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.point_of_sale_rounded, size: 14, color: AppColors.secondary),
                    label: Text('Buka Drawer', style: TextStyle(color: AppColors.secondary, fontSize: 11.5.sp)),
                    onPressed: () async {
                      final success = await ref.read(printerNotifierProvider.notifier).openCashDrawer(targetAddress: printer.address);
                      if (mounted) {
                        if (success) {
                          AppSnackbar.showSuccess(context, 'Perintah pembuka laci kasir berhasil dikirim.');
                        } else {
                          AppSnackbar.showWarning(context, 'Gagal membuka laci kasir. Pastikan printer terhubung.');
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
                    label: Text('Putuskan', style: TextStyle(color: AppColors.error, fontSize: 11.5.sp)),
                    onPressed: () async {
                      final success = await ref.read(printerNotifierProvider.notifier).deletePrinter(printer.id);
                      if (success && mounted) {
                        AppSnackbar.showSuccess(context, 'Printer kasir berhasil diputuskan.');
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
                child: Text(
                  'Belum ada printer kasir terkonfigurasi.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.disabled, fontStyle: FontStyle.italic),
                ),
              ),
            ),
            const SizedBox(height: 6),
            AppButton(
              text: 'Hubungkan Printer Kasir',
              icon: Icons.bluetooth_searching_rounded,
              onPressed: () => _showScanBottomSheet(context, initialType: 'cashier'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKitchenPrinterCard(PrinterConfigModel printer, dynamic categories) {
    final state = ref.watch(printerNotifierProvider);
    final isLoadingThisCard = state.isLoading && state.loadingType == printer.type;

    // Get mapped category names
    final mappedNames = <String>[];
    if (categories is List) {
      for (final catId in printer.categoryIds) {
        final found = categories.where((c) => c.id == catId).toList();
        if (found.isNotEmpty) {
          mappedNames.add(found.first.nama);
        }
      }
    }

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
                child: Row(
                  children: [
                    const Icon(Icons.soup_kitchen_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        printer.displayName,
                        style: AppTypography.titleMedium.copyWith(fontSize: 15.sp, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (printer.isConnected ? AppColors.success : AppColors.info).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  printer.isConnected ? 'Terhubung' : 'Tersimpan',
                  style: TextStyle(
                    color: printer.isConnected ? AppColors.success : AppColors.info,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (printer.label != null && printer.label!.isNotEmpty)
            Text('Device: ${printer.name} (${printer.address})', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 10.5.sp))
          else
            Text(printer.address, style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.sp)),
          const SizedBox(height: 8),

          // Category Chips
          Text('Kategori Menu Ditautkan:', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (mappedNames.isEmpty)
                Chip(
                  label: Text('Semua Kategori (Tanpa Filter)', style: TextStyle(fontSize: 10.5.sp, color: AppColors.primary)),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: AppColors.primaryContainer.withValues(alpha: 0.3),
                  side: const BorderSide(color: AppColors.primary),
                )
              else
                ...mappedNames.map((catName) => Chip(
                      label: Text(catName, style: TextStyle(fontSize: 10.5.sp)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.divider),
                    )),
            ],
          ),
          const Divider(height: 20),

          // Specs & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${printer.paperSize}mm • ${printer.effectiveCharsPerLine} char${printer.autoCut ? " • Auto Cut" : ""}',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11.sp),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (isLoadingThisCard)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              else
                Wrap(
                  spacing: 6,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                      tooltip: 'Ubah Pengaturan & Kategori',
                      onPressed: () => _showConfigDialog(existingPrinter: printer),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: AppColors.textSecondary),
                      tooltip: 'Preview Nota Dapur',
                      onPressed: () => _showPreviewDialog(printer),
                    ),
                    IconButton(
                      icon: const Icon(Icons.print_outlined, size: 18, color: AppColors.primary),
                      tooltip: 'Test Print Dapur',
                      onPressed: () => _handleTestPrint(printer),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                      tooltip: 'Hapus Printer',
                      onPressed: () async {
                        final success = await ref.read(printerNotifierProvider.notifier).deletePrinter(printer.id);
                        if (success && mounted) {
                          AppSnackbar.showSuccess(context, 'Printer dapur "${printer.displayName}" berhasil dihapus.');
                        }
                      },
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
