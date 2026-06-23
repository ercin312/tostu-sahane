import 'package:equatable/equatable.dart';

import 'product.dart';

enum PromotionType {
  percentDiscount,
  fixedDiscount,
  freeDrinks,
}

class PromotionCampaign extends Equatable {
  const PromotionCampaign({
    required this.id,
    required this.title,
    required this.type,
    this.code = '',
    this.value = 0,
    this.minOrderAmount = 0,
    this.autoApply = false,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final PromotionType type;
  /// Boşsa yalnızca otomatik kampanya olarak uygulanabilir.
  final String code;
  /// Yüzde veya sabit TL indirim tutarı; içecek kampanyasında kullanılmaz.
  final double value;
  final double minOrderAmount;
  final bool autoApply;
  final bool isActive;
  final int sortOrder;

  String get normalizedCode => code.trim().toUpperCase();

  bool get hasCode => normalizedCode.isNotEmpty;

  PromotionCampaign copyWith({
    String? id,
    String? title,
    PromotionType? type,
    String? code,
    double? value,
    double? minOrderAmount,
    bool? autoApply,
    bool? isActive,
    int? sortOrder,
  }) {
    return PromotionCampaign(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      code: code ?? this.code,
      value: value ?? this.value,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      autoApply: autoApply ?? this.autoApply,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type.name,
        'code': normalizedCode,
        'value': value,
        'min_order_amount': minOrderAmount,
        'auto_apply': autoApply,
        'is_active': isActive,
        'sort_order': sortOrder,
      };

  factory PromotionCampaign.fromJson(Map<String, dynamic> json) {
    return PromotionCampaign(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      type: PromotionType.values.byName(json['type'] as String),
      code: json['code'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble() ?? 0,
      autoApply: json['auto_apply'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        type,
        code,
        value,
        minOrderAmount,
        autoApply,
        isActive,
        sortOrder,
      ];
}

extension PromotionTypeLabels on PromotionType {
  String get localeKey => switch (this) {
        PromotionType.percentDiscount => 'admin_promotion_type_percent',
        PromotionType.fixedDiscount => 'admin_promotion_type_fixed',
        PromotionType.freeDrinks => 'admin_promotion_type_free_drinks',
      };
}

extension PromotionCategorySupport on PromotionType {
  ProductCategory? get targetCategory => switch (this) {
        PromotionType.freeDrinks => ProductCategory.drink,
        _ => null,
      };
}
