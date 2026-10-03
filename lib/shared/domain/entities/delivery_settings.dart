class DeliverySettings {
  const DeliverySettings({
    this.freeDeliveryMinOrder = 150,
    this.belowMinimumDeliveryFee = 0,
    this.upsellProductIds = const [],
  });

  /// Mobil sepette bu tutarın altında gönderim ücreti alınır.
  /// Bu tutar ve üzerinde gönderim ücreti yoktur.
  final double freeDeliveryMinOrder;

  /// Sepet [freeDeliveryMinOrder] altındayken kesilen gönderim ücreti.
  final double belowMinimumDeliveryFee;

  /// Sipariş tamamlanırken sepette sorulan ürünler. Sıra yönetici kaydıdır.
  final List<String> upsellProductIds;

  static const defaults = DeliverySettings();

  DeliverySettings copyWith({
    double? freeDeliveryMinOrder,
    double? belowMinimumDeliveryFee,
    List<String>? upsellProductIds,
  }) {
    return DeliverySettings(
      freeDeliveryMinOrder: freeDeliveryMinOrder ?? this.freeDeliveryMinOrder,
      belowMinimumDeliveryFee:
          belowMinimumDeliveryFee ?? this.belowMinimumDeliveryFee,
      upsellProductIds: upsellProductIds ?? this.upsellProductIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'free_delivery_min_order': freeDeliveryMinOrder,
        'below_minimum_delivery_fee': belowMinimumDeliveryFee,
        'upsell_product_ids': upsellProductIds,
      };

  factory DeliverySettings.fromJson(Map<String, dynamic> json) {
    final rawIds = json['upsell_product_ids'];
    final ids = rawIds is List
        ? rawIds.map((id) => id.toString()).where((id) => id.isNotEmpty).toList()
        : const <String>[];
    return DeliverySettings(
      freeDeliveryMinOrder:
          (json['free_delivery_min_order'] as num?)?.toDouble() ?? 150,
      belowMinimumDeliveryFee:
          (json['below_minimum_delivery_fee'] as num?)?.toDouble() ?? 0,
      upsellProductIds: ids,
    );
  }
}
