class PlatformSkuPriceModel {
  final String id;
  final String platformId;
  final String produkId;
  final double overridePrice;

  const PlatformSkuPriceModel({
    required this.id,
    required this.platformId,
    required this.produkId,
    required this.overridePrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'platform_id': platformId,
      'produk_id': produkId,
      'override_price': overridePrice,
    };
  }

  factory PlatformSkuPriceModel.fromMap(Map<String, dynamic> map) {
    return PlatformSkuPriceModel(
      id: map['id'] as String,
      platformId: map['platform_id'] as String,
      produkId: map['produk_id'] as String,
      overridePrice: (map['override_price'] as num).toDouble(),
    );
  }
}
