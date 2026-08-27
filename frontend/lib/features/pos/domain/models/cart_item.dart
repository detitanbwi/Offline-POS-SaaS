import '../../../product/domain/models/product.dart';
import '../../../../core/utils/currency_formatter.dart';

class CartItem {
  final Product product;
  final int qty;
  final String catatan;
  final int initialSavedQty;
  final String? batchId;
  final bool isBilled;
  final String? batchName;
  final double discountPercentage;
  final double discountAmount;
  final String discountType; // 'percent' or 'nominal'
  final List<SelectedModifier> selectedModifiers;

  const CartItem({
    required this.product,
    required this.qty,
    this.catatan = '',
    this.initialSavedQty = 0,
    this.batchId,
    this.isBilled = false,
    this.batchName,
    this.discountPercentage = 0.0,
    this.discountAmount = 0.0,
    this.discountType = 'percent',
    this.selectedModifiers = const [],
  });

  double get modifierUnitPrice => selectedModifiers.fold<double>(0.0, (sum, m) => sum + m.harga);
  double get baseUnitPrice => product.harga + modifierUnitPrice;
  double get grossSubtotal => baseUnitPrice * qty;
  double get subtotal => (grossSubtotal - discountAmount).clamp(0.0, double.infinity);
  double get effectivePrice => qty > 0 ? (subtotal / qty) : baseUnitPrice;
  bool get hasDiscount => discountAmount > 0;
  bool get hasModifiers => selectedModifiers.isNotEmpty;
  bool get canDecrement => qty > initialSavedQty;
  bool get isManual => product.id.startsWith('manual_');

  String get modifiersSummary => selectedModifiers
      .map((m) => '${m.optionName}${m.harga > 0 ? ' (+${CurrencyFormatter.format(m.harga)})' : ''}')
      .join(', ');

  String get modifierSignature {
    final sigs = selectedModifiers.map((m) => '${m.groupId}:${m.optionId}').toList()..sort();
    return sigs.join('|');
  }

  CartItem copyWith({
    Product? product,
    int? qty,
    String? catatan,
    int? initialSavedQty,
    String? batchId,
    bool? isBilled,
    String? batchName,
    double? discountPercentage,
    double? discountAmount,
    String? discountType,
    List<SelectedModifier>? selectedModifiers,
  }) {
    return CartItem(
      product: product ?? this.product,
      qty: qty ?? this.qty,
      catatan: catatan ?? this.catatan,
      initialSavedQty: initialSavedQty ?? this.initialSavedQty,
      batchId: batchId ?? this.batchId,
      isBilled: isBilled ?? this.isBilled,
      batchName: batchName ?? this.batchName,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountAmount: discountAmount ?? this.discountAmount,
      discountType: discountType ?? this.discountType,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
    );
  }
}
