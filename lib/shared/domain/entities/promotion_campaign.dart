import 'package:equatable/equatable.dart';

import 'product.dart';

enum PromotionType {
  percentDiscount,
  fixedDiscount,
  freeDrinks,
  freeItem,
  buyXGetY,
  freeDelivery,
}

class PromotionCampaign extends Equatable {
  const PromotionCampaign({
    required this.id,
    required this.title,
    required this.type,
    this.description = '',
    this.code = '',
    this.value = 0,
    this.minOrderAmount = 0,
    this.maxDiscount,
    this.autoApply = false,
    this.isActive = true,
    this.sortOrder = 0,
    this.expiresAt,
    this.startsAt,
    this.remainingUses,
    this.targetCategory,
    this.productIds = const [],
    this.rewardProductIds = const [],
    this.buyQuantity = 0,
    this.freeQuantity = 1,
    this.firstOrderOnly = false,
  });

  final String id;
  final String title;
  final String description;
  final PromotionType type;
  /// Boşsa yalnızca otomatik kampanya olarak uygulanabilir.
  final String code;
  /// Yüzde veya sabit TL indirim tutarı.
  final double value;
  final double minOrderAmount;
  /// Yüzde indirimde tavan. Boşsa sınır yok.
  final double? maxDiscount;
  final bool autoApply;
  final bool isActive;
  final int sortOrder;
  final DateTime? expiresAt;
  final DateTime? startsAt;
  /// null = sınırsız. 0 = hakkı kalmadı.
  final int? remainingUses;
  /// `ProductCategory.name`. Boşsa kategori sınırı yok.
  final String? targetCategory;
  /// Doluysa indirim yalnızca bu ürünlere uygulanır.
  final List<String> productIds;
  /// X al Y bedava kampanyasında bedava olan ürünler.
  final List<String> rewardProductIds;
  final int buyQuantity;
  final int freeQuantity;
  /// Yalnızca hiç sipariş vermemiş müşteriye gösterilir ve uygulanır.
  final bool firstOrderOnly;

  String get normalizedCode => code.trim().toUpperCase();

  bool get hasCode => normalizedCode.isNotEmpty;

  bool get hasScope =>
      productIds.isNotEmpty ||
      (targetCategory != null && targetCategory!.isNotEmpty);

  ProductCategory? get scopedCategory {
    final name = targetCategory;
    if (name == null || name.isEmpty || name == ProductCategory.all.name) {
      return null;
    }
    for (final category in ProductCategory.values) {
      if (category.name == name) return category;
    }
    return null;
  }

  bool get isExpired {
    final expiry = expiresAt;
    if (expiry == null) return false;
    return DateTime.now().isAfter(expiry);
  }

  bool get hasStarted {
    final start = startsAt;
    if (start == null) return true;
    return !DateTime.now().isBefore(start);
  }

  bool get hasUsesLeft => remainingUses == null || remainingUses! > 0;

  PromotionCampaign copyWith({
    String? id,
    String? title,
    String? description,
    PromotionType? type,
    String? code,
    double? value,
    double? minOrderAmount,
    double? maxDiscount,
    bool? autoApply,
    bool? isActive,
    int? sortOrder,
    DateTime? expiresAt,
    DateTime? startsAt,
    int? remainingUses,
    String? targetCategory,
    List<String>? productIds,
    List<String>? rewardProductIds,
    int? buyQuantity,
    int? freeQuantity,
    bool? firstOrderOnly,
    bool clearExpiresAt = false,
    bool clearStartsAt = false,
    bool clearRemainingUses = false,
    bool clearMaxDiscount = false,
    bool clearTargetCategory = false,
  }) {
    return PromotionCampaign(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      code: code ?? this.code,
      value: value ?? this.value,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      maxDiscount: clearMaxDiscount ? null : (maxDiscount ?? this.maxDiscount),
      autoApply: autoApply ?? this.autoApply,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
      startsAt: clearStartsAt ? null : (startsAt ?? this.startsAt),
      remainingUses:
          clearRemainingUses ? null : (remainingUses ?? this.remainingUses),
      targetCategory:
          clearTargetCategory ? null : (targetCategory ?? this.targetCategory),
      productIds: productIds ?? this.productIds,
      rewardProductIds: rewardProductIds ?? this.rewardProductIds,
      buyQuantity: buyQuantity ?? this.buyQuantity,
      freeQuantity: freeQuantity ?? this.freeQuantity,
      firstOrderOnly: firstOrderOnly ?? this.firstOrderOnly,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'code': normalizedCode,
        'value': value,
        'min_order_amount': minOrderAmount,
        if (maxDiscount != null) 'max_discount': maxDiscount,
        'auto_apply': autoApply,
        'is_active': isActive,
        'sort_order': sortOrder,
        if (expiresAt != null) 'expires_at': expiresAt!.toUtc().toIso8601String(),
        if (startsAt != null) 'starts_at': startsAt!.toUtc().toIso8601String(),
        if (remainingUses != null) 'remaining_uses': remainingUses,
        if (targetCategory != null && targetCategory!.isNotEmpty)
          'target_category': targetCategory,
        'product_ids': productIds,
        'reward_product_ids': rewardProductIds,
        'buy_quantity': buyQuantity,
        'free_quantity': freeQuantity,
        'first_order_only': firstOrderOnly,
      };

  static DateTime? _readDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String && raw.isNotEmpty) return DateTime.tryParse(raw);
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true);
    }
    return null;
  }

  static List<String> _readIds(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((id) => id.toString()).where((id) => id.isNotEmpty).toList();
  }

  factory PromotionCampaign.fromJson(Map<String, dynamic> json) {
    final maxRaw = json['max_discount'];
    return PromotionCampaign(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: PromotionType.values.byName(json['type'] as String),
      code: json['code'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? 0,
      minOrderAmount: (json['min_order_amount'] as num?)?.toDouble() ?? 0,
      maxDiscount: maxRaw is num && maxRaw > 0 ? maxRaw.toDouble() : null,
      autoApply: json['auto_apply'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
      expiresAt: _readDate(json['expires_at']),
      startsAt: _readDate(json['starts_at']),
      remainingUses: (json['remaining_uses'] as num?)?.toInt(),
      targetCategory: json['target_category'] as String?,
      productIds: _readIds(json['product_ids']),
      rewardProductIds: _readIds(json['reward_product_ids']),
      buyQuantity: (json['buy_quantity'] as num?)?.toInt() ?? 0,
      freeQuantity: (json['free_quantity'] as num?)?.toInt() ?? 1,
      firstOrderOnly: json['first_order_only'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        type,
        code,
        value,
        minOrderAmount,
        maxDiscount,
        autoApply,
        isActive,
        sortOrder,
        expiresAt,
        startsAt,
        remainingUses,
        targetCategory,
        productIds,
        rewardProductIds,
        buyQuantity,
        freeQuantity,
        firstOrderOnly,
      ];
}

extension PromotionTypeLabels on PromotionType {
  String get localeKey => switch (this) {
        PromotionType.percentDiscount => 'admin_promotion_type_percent',
        PromotionType.fixedDiscount => 'admin_promotion_type_fixed',
        PromotionType.freeDrinks => 'admin_promotion_type_free_drinks',
        PromotionType.freeItem => 'admin_promotion_type_free_item',
        PromotionType.buyXGetY => 'admin_promotion_type_bogo',
        PromotionType.freeDelivery => 'admin_promotion_type_free_delivery',
      };

  String get hintKey => switch (this) {
        PromotionType.percentDiscount => 'admin_promotion_type_hint_percent',
        PromotionType.fixedDiscount => 'admin_promotion_type_hint_fixed',
        PromotionType.freeDrinks => 'admin_promotion_type_hint_drinks',
        PromotionType.freeItem => 'admin_promotion_type_hint_item',
        PromotionType.buyXGetY => 'admin_promotion_type_hint_bogo',
        PromotionType.freeDelivery => 'admin_promotion_type_hint_delivery',
      };
}

extension PromotionCategorySupport on PromotionType {
  ProductCategory? get targetCategory => switch (this) {
        PromotionType.freeDrinks => ProductCategory.drink,
        _ => null,
      };
}
