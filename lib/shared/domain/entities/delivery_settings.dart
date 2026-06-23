class DeliverySettings {
  const DeliverySettings({
    this.freeDeliveryMinOrder = 150,
  });

  /// Bu tutarın üzerindeki siparişlerde paket servis ücreti alınmaz.
  final double freeDeliveryMinOrder;

  static const defaults = DeliverySettings();

  DeliverySettings copyWith({double? freeDeliveryMinOrder}) {
    return DeliverySettings(
      freeDeliveryMinOrder: freeDeliveryMinOrder ?? this.freeDeliveryMinOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'free_delivery_min_order': freeDeliveryMinOrder,
      };

  factory DeliverySettings.fromJson(Map<String, dynamic> json) {
    return DeliverySettings(
      freeDeliveryMinOrder:
          (json['free_delivery_min_order'] as num?)?.toDouble() ?? 150,
    );
  }
}
