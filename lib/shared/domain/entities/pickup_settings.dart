import 'promotion_campaign.dart';

/// Mobil uygulamadaki Gel Al bölümü. Yönetici açar, fiyat ve kampanya tanımlar.
class PickupSettings {
  const PickupSettings({
    this.enabled = true,
    this.badgeText = 'Şubeden teslim',
    this.headline = 'Gel Al',
    this.subtitle = 'Kurye bekleme. Siparişin hazır olunca şubeden al.',
    this.readyMinutes = 15,
    this.minOrderAmount = 0,
    this.productPrices = const {},
    this.campaigns = const [],
  });

  final bool enabled;
  final String badgeText;
  final String headline;
  final String subtitle;
  /// Müşteriye gösterilen hazır olma süresi (dakika).
  final int readyMinutes;
  /// 0 ise Gel Al için alt limit yok.
  final double minOrderAmount;
  /// Ürün id → Gel Al fiyatı. Kayıt yoksa menü fiyatı kullanılır.
  final Map<String, double> productPrices;
  final List<PromotionCampaign> campaigns;

  static const defaults = PickupSettings();

  double priceFor(String productId, double menuPrice) {
    final override = productPrices[productId];
    if (override == null || override < 0) return menuPrice;
    return override;
  }

  bool hasDiscount(String productId, double menuPrice) {
    return priceFor(productId, menuPrice) + 0.009 < menuPrice;
  }

  List<PromotionCampaign> get activeCampaigns {
    final list = campaigns
        .where((campaign) => campaign.isActive && !campaign.isExpired && campaign.hasUsesLeft)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  PickupSettings copyWith({
    bool? enabled,
    String? badgeText,
    String? headline,
    String? subtitle,
    int? readyMinutes,
    double? minOrderAmount,
    Map<String, double>? productPrices,
    List<PromotionCampaign>? campaigns,
  }) {
    return PickupSettings(
      enabled: enabled ?? this.enabled,
      badgeText: badgeText ?? this.badgeText,
      headline: headline ?? this.headline,
      subtitle: subtitle ?? this.subtitle,
      readyMinutes: readyMinutes ?? this.readyMinutes,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      productPrices: productPrices ?? this.productPrices,
      campaigns: campaigns ?? this.campaigns,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'badge_text': badgeText,
        'headline': headline,
        'subtitle': subtitle,
        'ready_minutes': readyMinutes,
        'min_order_amount': minOrderAmount,
        'product_prices': productPrices,
        'campaigns': campaigns.map((campaign) => campaign.toJson()).toList(),
      };

  static Map<String, double> _readPriceMap(dynamic raw) {
    if (raw is! Map) return const {};
    final out = <String, double>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is! num || value < 0) continue;
      out[entry.key.toString()] = value.toDouble();
    }
    return out;
  }

  static List<PromotionCampaign> _readCampaigns(dynamic raw) {
    if (raw is! List) return const [];
    final out = <PromotionCampaign>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        out.add(
          PromotionCampaign.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {}
    }
    out.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return out;
  }

  factory PickupSettings.fromJson(Map<String, dynamic> json) {
    final badge = (json['badge_text'] as String?)?.trim();
    final headline = (json['headline'] as String?)?.trim();
    final subtitle = (json['subtitle'] as String?)?.trim();
    final minutes = (json['ready_minutes'] as num?)?.toInt() ?? 15;
    final minOrder = (json['min_order_amount'] as num?)?.toDouble() ?? 0;
    return PickupSettings(
      enabled: json['enabled'] as bool? ?? true,
      badgeText: (badge == null || badge.isEmpty) ? defaults.badgeText : badge,
      headline: (headline == null || headline.isEmpty) ? defaults.headline : headline,
      subtitle: (subtitle == null || subtitle.isEmpty) ? defaults.subtitle : subtitle,
      readyMinutes: minutes.clamp(5, 180),
      minOrderAmount: minOrder.clamp(0, 100000),
      productPrices: _readPriceMap(json['product_prices']),
      campaigns: _readCampaigns(json['campaigns']),
    );
  }
}
