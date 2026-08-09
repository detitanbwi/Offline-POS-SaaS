import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../../../auth/presentation/screens/pin_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../pos/presentation/screens/order_hub_screen.dart';
import '../../../pos/presentation/screens/sales_report_screen.dart';
import '../../../category/presentation/screens/category_screen.dart';
import '../../../product/presentation/screens/product_screen.dart';
import '../../../stock/presentation/screens/stock_in_screen.dart';
import '../../../payment_method/presentation/screens/payment_method_screen.dart';
import '../../../tax/presentation/screens/tax_setting_screen.dart';
import '../../../transaction_history/presentation/screens/transaction_history_screen.dart';
import '../../../table/presentation/screens/table_screen.dart';
import '../../../pos/presentation/screens/online_platform_master_screen.dart';
import '../../../../core/di/providers.dart';
import '../../../printer/presentation/screens/printer_setting_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../cashier/presentation/screens/cashier_management_screen.dart';

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Keluar / Kunci Sesi',
                  style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pilih opsi di bawah untuk mengunci aplikasi atau keluar dari akun SaaS.',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Kunci Layar / Ganti User'),
                  onPressed: () {
                    ref.read(authSessionProvider.notifier).state = null;
                    Navigator.pop(sheetContext);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const PinScreen(isSetup: false)),
                    );
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Keluar Akun SaaS (Logout)'),
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _confirmSaaSLogout(context, ref);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmSaaSLogout(BuildContext context, WidgetRef ref) {
    AppDialog.show(
      context: context,
      title: 'Logout SaaS',
      message: 'Apakah Anda yakin ingin keluar dari akun SaaS? Token aktivasi online akan dihapus.',
      confirmText: 'Logout',
      isDestructive: true,
      onConfirm: () async {
        // Tutup dialog terlebih dahulu
        Navigator.of(context, rootNavigator: true).pop();

        final storage = ref.read(secureStorageServiceProvider);
        await storage.clearAll();
        ref.read(authSessionProvider.notifier).state = null;

        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      },
    );
  }

  void _showMasterDataSubmenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kelola Master Data',
                      style: AppTypography.titleLarge.copyWith(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
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
                  title: 'Platform Online (Take Away)',
                  description: 'Kelola platform pesanan online',
                  icon: Icons.delivery_dining_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OnlinePlatformMasterScreen()));
                  },
                ),
              ],
            ),
          ),
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
              color: AppColors.primaryContainer.withValues(alpha: 0.4),

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
    final activeUser = ref.watch(authSessionProvider);

    if (activeUser == null) {
      // Safety redirect/placeholder
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isOwner = activeUser.isOwner;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(isOwner ? 'Dashboard Pemilik POS' : 'Dashboard Kasir POS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_rounded),
            tooltip: 'Kunci Sesi / Logout',
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
                isOwner ? 'Selamat Datang, Pemilik Toko!' : 'Selamat Datang, ${activeUser.nama}!',
                style: AppTypography.headlineLarge.copyWith(fontSize: 28),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isOwner 
                    ? 'Kelola akun kasir, master data produk, dan pengaturan sistem Anda.'
                    : 'Sistem POS berjalan penuh secara offline. Silakan pilih menu di bawah.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: ResponsiveLayout(
                  mobile: _buildGrid(context, ref, isOwner, isTablet: false),
                  tablet: _buildGrid(context, ref, isOwner, isTablet: true),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref, bool isOwner, {required bool isTablet}) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final int crossAxisCount;
    final double childAspectRatio;

    if (!isTablet) {
      if (isLandscape) {
        crossAxisCount = isOwner ? 3 : 4;
        childAspectRatio = 1.35;
      } else {
        crossAxisCount = 2;
        childAspectRatio = 1.1;
      }
    } else {
      if (isLandscape) {
        crossAxisCount = isOwner ? 3 : 4;
        childAspectRatio = 1.35;
      } else {
        crossAxisCount = isOwner ? 3 : 3;
        childAspectRatio = 1.2;
      }
    }

    if (isOwner) {
      return GridView.count(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.m,
        mainAxisSpacing: AppSpacing.m,
        childAspectRatio: childAspectRatio,
        children: [
          _buildMenuCard(
            context,
            title: 'Kelola Akun Kasir',
            subtitle: 'Daftar, reset PIN & status kasir',
            icon: Icons.people_rounded,
            color: Colors.teal.shade50,
            iconColor: Colors.teal.shade700,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CashierManagementScreen()));
            },
          ),
          _buildMenuCard(
            context,
            title: 'Master Data Toko',
            subtitle: 'Kategori, Produk, Stok & Pajak',
            icon: Icons.inventory_rounded,
            color: AppColors.secondaryContainer,
            iconColor: AppColors.secondary,
            onTap: () => _showMasterDataSubmenu(context),
          ),
          _buildMenuCard(
            context,
            title: 'Pengaturan Sistem',
            subtitle: 'Printer, Database & Lisensi SaaS',
            icon: Icons.settings_rounded,
            color: Colors.purple.shade50,
            iconColor: Colors.purple.shade700,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      );
    } else {
      // Cashier View
      return GridView.count(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.m,
        mainAxisSpacing: AppSpacing.m,
        childAspectRatio: childAspectRatio,
        children: [
          _buildMenuCard(
            context,
            title: 'Transaksi POS',
            subtitle: 'Mulai melayani pelanggan',
            icon: Icons.point_of_sale_rounded,
            color: AppColors.primaryContainer,
            iconColor: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OrderHubScreen(),
                  settings: const RouteSettings(name: '/order_hub'),
                ),
              );
            },
          ),
          _buildMenuCard(
            context,
            title: 'Kelola Meja Makan',
            subtitle: 'Kelola meja restoran & status',
            icon: Icons.table_restaurant_rounded,
            color: Colors.orange.shade50,
            iconColor: Colors.orange.shade700,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const TableScreen()));
            },
          ),
          _buildMenuCard(
            context,
            title: 'Konfigurasi Printer',
            subtitle: 'Scan & hubungkan printer bluetooth',
            icon: Icons.print_rounded,
            color: Colors.blue.shade50,
            iconColor: Colors.blue.shade700,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrinterSettingScreen()));
            },
          ),
          _buildMenuCard(
            context,
            title: 'Riwayat Transaksi',
            subtitle: 'Cari & batalkan struk (Void)',
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
            subtitle: 'Ringkasan shift & ekspor PDF',
            icon: Icons.analytics_rounded,
            color: Colors.indigo.shade50,
            iconColor: Colors.indigo.shade700,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesReportScreen()));
            },
          ),
        ],
      );
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.titleMedium.copyWith(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

