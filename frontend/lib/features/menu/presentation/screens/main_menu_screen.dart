import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/services/secure_storage_service.dart';
import '../../../pos/presentation/screens/pos_screen.dart';
import '../../../pos/presentation/screens/table_selector_screen.dart';
import '../../../pos/presentation/screens/sales_report_screen.dart';
import '../../../category/presentation/screens/category_screen.dart';
import '../../../product/presentation/screens/product_screen.dart';
import '../../../stock/presentation/screens/stock_in_screen.dart';
import '../../../payment_method/presentation/screens/payment_method_screen.dart';
import '../../../tax/presentation/screens/tax_setting_screen.dart';
import '../../../transaction_history/presentation/screens/transaction_history_screen.dart';
import '../../../table/presentation/screens/table_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/providers.dart';
import '../../../printer/presentation/screens/printer_setting_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    AppDialog.show(
      context: context,
      title: 'Logout',
      message: 'Apakah Anda yakin ingin logout? Data token online akan dihapus.',
      confirmText: 'Logout',
      isDestructive: true,
      onConfirm: () async {
        final storage = ref.read(secureStorageServiceProvider);
        await storage.clearAll();
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      },
    );
  }

  void _showMasterDataSubmenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Kelola Master Data',
                  style: AppTypography.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSubmenuItem(
              context,
              title: 'Kategori Produk',
              description: 'Kelola kategori untuk klasifikasi produk',
              icon: Icons.category_outlined,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryScreen()));
              },
            ),
            const SizedBox(height: 12),
            _buildSubmenuItem(
              context,
              title: 'Produk',
              description: 'Kelola nama, harga, dan status produk',
              icon: Icons.inventory_2_outlined,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductScreen()));
              },
            ),
            const SizedBox(height: 12),
            _buildSubmenuItem(
              context,
              title: 'Stok Masuk (Stock In)',
              description: 'Catat penambahan stok produk',
              icon: Icons.add_business_outlined,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StockInScreen()));
              },
            ),
            const SizedBox(height: 12),
            _buildSubmenuItem(
              context,
              title: 'Meja Restoran',
              description: 'Kelola meja makan & status',
              icon: Icons.table_restaurant_outlined,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TableScreen()));
              },
            ),
            const SizedBox(height: 12),
            _buildSubmenuItem(
              context,
              title: 'Metode Pembayaran',
              description: 'Kelola metode pembayaran kasir',
              icon: Icons.payments_outlined,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentMethodScreen()));
              },
            ),
            const SizedBox(height: 12),
            _buildSubmenuItem(
              context,
              title: 'Pengaturan Pajak',
              description: 'Atur aktifasi dan persentase pajak (PPN)',
              icon: Icons.percent_outlined,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TaxSettingScreen()));
              },
            ),
            const SizedBox(height: 12),
            _buildSubmenuItem(
              context,
              title: 'Konfigurasi Printer',
              description: 'Atur printer struk kasir & tiket dapur',
              icon: Icons.print_rounded,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmenuItem(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderSide: const BorderSide(color: AppColors.divider),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMedium.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(description, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Dashboard Kasir POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Selamat Datang, Kasir!',
                style: AppTypography.headlineLarge.copyWith(fontSize: 28),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sistem POS berjalan penuh secara offline. Silakan pilih menu di bawah.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ResponsiveLayout(
                  mobile: _buildGrid(context, crossAxisCount: 2),
                  tablet: _buildGrid(context, crossAxisCount: 3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, {required int crossAxisCount}) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: AppSpacing.m,
      mainAxisSpacing: AppSpacing.m,
      children: [
        _buildMenuCard(
          context,
          title: 'Transaksi POS',
          subtitle: 'Mulai melayani pelanggan',
          icon: Icons.point_of_sale_rounded,
          color: AppColors.primaryContainer,
          iconColor: AppColors.primary,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TableSelectorScreen()));
          },
        ),
        _buildMenuCard(
          context,
          title: 'Master Data',
          subtitle: 'Produk, Kategori, Stok & Pajak',
          icon: Icons.inventory_rounded,
          color: AppColors.secondaryContainer,
          iconColor: AppColors.secondary,
          onTap: () => _showMasterDataSubmenu(context),
        ),
        _buildMenuCard(
          context,
          title: 'Riwayat Transaksi',
          subtitle: 'Lihat & cetak struk lama',
          icon: Icons.history_rounded,
          color: Colors.green.shade50,
          iconColor: Colors.green.shade700,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()));
          },
        ),
        _buildMenuCard(
          context,
          title: 'Laporan Penjualan',
          subtitle: 'Statistik omset & terlaris harian',
          icon: Icons.analytics_rounded,
          color: Colors.blue.shade50,
          iconColor: Colors.blue.shade700,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen()));
          },
        ),
        _buildMenuCard(
          context,
          title: 'Pengaturan Sistem',
          subtitle: 'Printer, Database & Informasi',
          icon: Icons.settings_rounded,
          color: Colors.purple.shade50,
          iconColor: Colors.purple.shade700,
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          },
        ),
      ],
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      color: Colors.white,
      padding: const EdgeInsets.all(AppSpacing.l),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.titleMedium.copyWith(fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
