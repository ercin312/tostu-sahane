import 'package:equatable/equatable.dart';

enum CouponType { percent, fixed }

class Coupon extends Equatable {
  const Coupon({
    required this.code,
    required this.type,
    required this.value,
    this.minOrderAmount = 0,
    this.isActive = true,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) => Coupon(
        code: json['code'] as String,
        type: CouponType.values.byName(json['type'] as String),
        value: (json['value'] as num).toDouble(),
        minOrderAmount: (json['min_order_amount'] as num?)?.toDouble() ?? 0,
        isActive: json['is_active'] as bool? ?? true,
      );

  final String code;
  final CouponType type;
  final double value;
  final double minOrderAmount;
  final bool isActive;

  double discountFor(double subtotal) {
    if (!isActive || subtotal < minOrderAmount) return 0;
    return switch (type) {
      CouponType.percent => subtotal * (value / 100),
      CouponType.fixed => value.clamp(0, subtotal),
    };
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'type': type.name,
        'value': value,
        'min_order_amount': minOrderAmount,
        'is_active': isActive,
      };

  @override
  List<Object?> get props => [code, type, value, minOrderAmount, isActive];
}
