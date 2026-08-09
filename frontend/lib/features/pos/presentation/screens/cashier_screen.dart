import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/responsive_layout.dart';
import '../../../category/application/category_notifier.dart';
import '../../../product/application/product_notifier.dart';
import '../../application/cart_notifier.dart';
import '../../application/order_notifier.dart';

import '../widgets/cashier_catalog_section.dart';
import '../widgets/cashier_cart_section.dart';

class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> with SingleTickerProviderStateMixin {
  late TabController _mobileTabController;

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productNotifierProvider.notifier).loadProducts();
      ref.read(categoryNotifierProvider.notifier).loadCategories();
    });
  }

  @override
  void dispose() {
    _mobileTabController.dispose();
    super.dispose();
  }

  void _onSaveCompleted() {
    Navigator.popUntil(context, (route) => route.settings.name == '/order_hub' || route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderNotifierProvider);
    final cartState = ref.watch(cartNotifierProvider);

    final String tableName = orderState.selectedTable?.nama ?? orderState.activeOrder?.tableNama ?? orderState.activeOrder?.tableNomor ?? '';
    final titleText = orderState.isTakeAway
        ? 'Take Away (${orderState.takeAwaySubType == 'online_food' ? 'Online Food' : 'Reguler'})'
        : (tableName.isNotEmpty ? tableName : 'Kasir POS');

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(titleText),
        actions: [
          if (cartState.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${cartState.items.fold(0, (sum, i) => sum + i.qty)} item',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveLayout(
          // Tablet / POS Stand (Landscape Split View)
          tablet: Padding(
            padding: const EdgeInsets.all(AppSpacing.m),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left 60%: Catalog
                const Expanded(
                  flex: 6,
                  child: CashierCatalogSection(),
                ),
                const SizedBox(width: AppSpacing.m),
                const VerticalDivider(width: 1, color: AppColors.divider),
                const SizedBox(width: AppSpacing.m),
                // Right 40%: Cart & Actions
                Expanded(
                  flex: 4,
                  child: CashierCartSection(
                    onSaveDraftCompleted: _onSaveCompleted,
                  ),
                ),
              ],
            ),
          ),

          // Mobile / HP (Portrait with Tab / Vertical Switcher)
          mobile: Column(
            children: [
              // Tab bar for mobile
              Container(
                color: AppColors.background,
                child: TabBar(
                  controller: _mobileTabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: [
                    const Tab(icon: Icon(Icons.restaurant_menu_rounded), text: 'Katalog Menu'),
                    Tab(
                      icon: Badge(
                        label: Text('${cartState.items.length}'),
                        isLabelVisible: cartState.items.isNotEmpty,
                        child: const Icon(Icons.shopping_cart_rounded),
                      ),
                      text: 'Keranjang',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.m),
                  child: TabBarView(
                    controller: _mobileTabController,
                    children: [
                      const CashierCatalogSection(),
                      CashierCartSection(
                        onSaveDraftCompleted: _onSaveCompleted,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
