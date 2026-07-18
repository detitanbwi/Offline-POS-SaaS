import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/widgets/app_button.dart';
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
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      bytes += generator.text(
        'KASIR POS OFFLINE',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        'TEST PRINT SUKSES',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.text(
        '==============================================',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Nama Printer : ${printer.name}',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Tipe         : ${printer.isCashier ? "Kasir Utama" : "Dapur/Kitchen"}',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Waktu        : ${DateTime.now().toString().split('.').first}',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        'Status       : TERHUBUNG',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.text(
        '==============================================',
        styles: const PosStyles(align: PosAlign.left),
      );
      bytes += generator.feed(3);
      // bytes += generator.cut();

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
                  Expanded(
                    child: state.scannedDevices.isEmpty
                        ? const AppEmptyState(
                            title: 'Tidak Ada Perangkat Bluetooth',
                            description: 'Pastikan Bluetooth perangkat menyala dan printer termal berpasangan (paired).',
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
                                title: Text(dev.name, style: AppTypography.titleMedium.copyWith(fontSize: 14)),
                                subtitle: Text(dev.address, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context); // Pop bottom sheet using its local context
                                        _setupPrinterConfig(this.context, dev.name, dev.address, 'cashier'); // Use screen context (mounted)
                                      },
                                      child: const Text('Kasir'),
                                    ),
                                    const SizedBox(width: 4),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context); // Pop bottom sheet using its local context
                                        _setupPrinterConfig(this.context, dev.name, dev.address, 'kitchen'); // Use screen context (mounted)
                                      },
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

  Future<void> _setupPrinterConfig(BuildContext context, String name, String address, String type) async {
    debugPrint('[PrinterSetting] _setupPrinterConfig called for $name ($address) type $type');

    AppDialog.show(
      context: context,
      title: 'Hubungkan Printer',
      message: 'Hubungkan "$name" sebagai Printer ${type == "cashier" ? "Kasir Utama" : "Dapur"}?',
      confirmText: 'Hubungkan',
      onConfirm: () async {
        debugPrint('[PrinterSetting] Confirm clicked');
        try {
          Navigator.of(context).pop(); // Close confirm dialog safely
          debugPrint('[PrinterSetting] Confirm dialog popped');
        } catch (e) {
          debugPrint('[PrinterSetting] Error popping confirm dialog: $e');
        }

        try {
          debugPrint('[PrinterSetting] Starting saveAndConnectPrinter');
          final success = await ref.read(printerNotifierProvider.notifier).saveAndConnectPrinter(
                name: name,
                address: address,
                type: type,
              );
          debugPrint('[PrinterSetting] saveAndConnectPrinter result: $success');
          
          if (!context.mounted) {
            debugPrint('[PrinterSetting] Context is not mounted after saveAndConnectPrinter');
            return;
          }
          
          if (success) {
            final err = ref.read(printerNotifierProvider).errorMessage;
            debugPrint('[PrinterSetting] Success, error message: $err');
            if (err != null) {
              AppSnackbar.showWarning(context, err);
            } else {
              AppSnackbar.showSuccess(context, 'Berhasil menghubungkan printer $name');
            }
          } else {
            final err = ref.read(printerNotifierProvider).errorMessage;
            debugPrint('[PrinterSetting] Failed, error message: $err');
            AppSnackbar.showError(context, err ?? 'Gagal menghubungkan printer.');
          }
        } catch (e, stack) {
          debugPrint('[PrinterSetting] Exception during confirm action: $e');
          debugPrint('[PrinterSetting] Stacktrace: $stack');
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
                    Text('Konfigurasi Printer 58mm', style: AppTypography.headlineLarge.copyWith(fontSize: 24)),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Pilih printer thermal bluetooth untuk mencetak struk belanja kasir dan tiket pesanan ke dapur.',
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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isLoadingThisCard)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  OutlinedButton.icon(
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Test Print'),
                    onPressed: () => _handleTestPrint(printer),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.link_off_rounded, size: 16, color: AppColors.error),
                    label: const Text('Putuskan', style: TextStyle(color: AppColors.error)),
                    onPressed: () async {
                      final success = await ref.read(printerNotifierProvider.notifier).deletePrinter(printer.id);
                      if (success && mounted) {
                        AppSnackbar.showSuccess(context, 'Printer berhasil diputuskan.');
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ],
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
