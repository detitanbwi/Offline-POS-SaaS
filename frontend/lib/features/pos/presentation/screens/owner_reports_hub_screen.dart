import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../transaction_history/presentation/screens/transaction_history_screen.dart';
import '../../../stock/presentation/screens/stock_mutation_report_screen.dart';
import 'sales_report_screen.dart';

class OwnerReportsHubScreen extends StatelessWidget {
  const OwnerReportsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppBar(
          title: const Text('Laporan & Riwayat'),
          bottom: TabBar(
            indicatorColor: AppColors.secondary,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: AppTypography.titleMedium.copyWith(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(
                icon: Icon(Icons.history_rounded),
                text: 'Riwayat Transaksi',
              ),
              Tab(
                icon: Icon(Icons.analytics_rounded),
                text: 'Laporan Penjualan',
              ),
              Tab(
                icon: Icon(Icons.swap_vert_circle_rounded),
                text: 'Mutasi Stok',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TransactionHistoryScreen(isEmbedded: true),
            SalesReportScreen(isEmbedded: true),
            StockMutationReportScreen(isEmbedded: true),
          ],
        ),
      ),
    );
  }
}
