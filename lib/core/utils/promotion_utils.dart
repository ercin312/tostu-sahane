import '../../shared/domain/entities/order.dart';
import '../../shared/domain/entities/product.dart';
import '../../shared/domain/entities/product_extra.dart';
import '../../shared/domain/entities/promotion_campaign.dart';

abstract final class PromotionUtils {
  static bool isEligible({
    required PromotionCampaign campaign,
    required double subtotal,
    bool isFirstOrder = true,
  }) {
    if (campaign.firstOrderOnly && !isFirstOrder) return false;
    if (!campaign.isActive ||
        campaign.isExpired ||
        !campaign.hasStarted ||
        !campaign.hasUsesLeft) {
      return false;
    }
    return subtotal >= campaign.minOrderAmount;
  }

  static double amountStillNeeded({
    required PromotionCampaign campaign,
    required double subtotal,
  }) {
    if (subtotal >= campaign.minOrderAmount) return 0;
    return campaign.minOrderAmount - subtotal;
  }

  /// Sepette seçilebilir: aktif, süresi dolmamış, hakkı var.
  /// Minimum tutar yetmese bile listelenir (Yemeksepeti “daha ekle” bandı).
  static bool canOfferInPicker(
    PromotionCampaign campaign, {
    bool isFirstOrder = true,
  }) {
    if (campaign.firstOrderOnly && !isFirstOrder) return false;
    return campaign.isActive &&
        !campaign.isExpired &&
        campaign.hasStarted &&
        campaign.hasUsesLeft;
  }

  /// İçecek sayılan ekstralar: malzeme değil, yiyecek ürünüyle eşleşmeyen yan ürünler.
  static Map<String, double> drinkExtraPriceMap({
    required List<Product> products,
    required List<ProductExtra> extras,
  }) {
    final byName = <String, List<Product>>{};
    for (final product in products) {
      byName.putIfAbsent(product.nameKey, () => []).add(product);
    }
    final prices = <String, double>{};
    for (final extra in extras) {
      if (extra.isToastIngredient || extra.price <= 0) continue;
      final twins = byName[extra.name] ?? const <Product>[];
      final matchesFood = twins.any(
        (product) =>
            product.category != ProductCategory.drink &&
            product.category != ProductCategory.all,
      );
      if (matchesFood) continue;
      prices[extra.id] = extra.price;
    }
    return prices;
  }

  static bool appliesToCart({
    required PromotionCampaign campaign,
    required List<CartItem> cartItems,
    required Map<String, ProductCategory> productCategories,
    Map<String, double> drinkExtraPrices = const {},
  }) {
    return switch (campaign.type) {
      PromotionType.freeDelivery => true,
      PromotionType.freeDrinks => _hasDrink(
          cartItems,
          productCategories,
          drinkExtraPrices,
        ),
      PromotionType.buyXGetY =>
        _conditionQuantity(campaign, cartItems, productCategories) >=
                campaign.buyQuantity &&
            campaign.buyQuantity > 0 &&
            _rewardLines(campaign, cartItems, productCategories).isNotEmpty,
      PromotionType.freeItem =>
        _matchingLines(campaign, cartItems, productCategories).isNotEmpty,
      PromotionType.percentDiscount || PromotionType.fixedDiscount =>
        !campaign.hasScope ||
            _matchingLines(campaign, cartItems, productCategories).isNotEmpty,
    };
  }

  static double discountFor({
    required PromotionCampaign campaign,
    required double subtotal,
    required List<CartItem> cartItems,
    required Map<String, ProductCategory> productCategories,
    double deliveryFee = 0,
    bool isFirstOrder = true,
    Map<String, double> drinkExtraPrices = const {},
  }) {
    if (!isEligible(
      campaign: campaign,
      subtotal: subtotal,
      isFirstOrder: isFirstOrder,
    )) {
      return 0;
    }

    return switch (campaign.type) {
      PromotionType.percentDiscount => _capped(
          _scopedBase(campaign, subtotal, cartItems, productCategories) *
              (campaign.value.clamp(0, 100) / 100),
          campaign,
          subtotal,
        ),
      PromotionType.fixedDiscount => _capped(
          campaign.value.clamp(
            0,
            _scopedBase(campaign, subtotal, cartItems, productCategories),
          ),
          campaign,
          subtotal,
        ),
      PromotionType.freeDrinks => _freeCategoryDiscount(
          cartItems: cartItems,
          productCategories: productCategories,
          category: ProductCategory.drink,
          subtotal: subtotal,
          drinkExtraPrices: drinkExtraPrices,
        ),
      PromotionType.freeItem => _cheapestUnits(
          _matchingLines(campaign, cartItems, productCategories),
          campaign.freeQuantity <= 0 ? 1 : campaign.freeQuantity,
        ).clamp(0, subtotal),
      PromotionType.buyXGetY => _buyXGetYDiscount(
          campaign,
          cartItems,
          productCategories,
          subtotal,
        ),
      PromotionType.freeDelivery => deliveryFee < 0 ? 0 : deliveryFee,
    };
  }

  static double _scopedBase(
    PromotionCampaign campaign,
    double subtotal,
    List<CartItem> cartItems,
    Map<String, ProductCategory> productCategories,
  ) {
    if (!campaign.hasScope) return subtotal;
    return _matchingLines(campaign, cartItems, productCategories)
        .fold<double>(0, (sum, item) => sum + item.totalPrice);
  }

  static double _capped(double amount, PromotionCampaign campaign, double subtotal) {
    var next = amount;
    final cap = campaign.maxDiscount;
    if (cap != null && cap > 0 && next > cap) next = cap;
    if (next < 0) return 0;
    if (next > subtotal) return subtotal;
    return next;
  }

  static ProductCategory? _categoryOf(
    CartItem item,
    Map<String, ProductCategory> productCategories,
  ) {
    final mapped = productCategories[item.productId];
    if (mapped != null && mapped != ProductCategory.all) return mapped;
    final raw = item.productCategory;
    if (raw == null || raw.isEmpty) return mapped;
    return ProductCategory.values.asNameMap()[raw] ?? mapped;
  }

  static bool _hasDrink(
    List<CartItem> cartItems,
    Map<String, ProductCategory> productCategories,
    Map<String, double> drinkExtraPrices,
  ) {
    for (final item in cartItems) {
      if (_categoryOf(item, productCategories) == ProductCategory.drink) {
        return true;
      }
      if (item.selectedOptions.any((id) => (drinkExtraPrices[id] ?? 0) > 0)) {
        return true;
      }
    }
    return false;
  }

  /// İçecek kampanyası sepetteki en ucuz bir adet içeceği düşer.
  static double _freeCategoryDiscount({
    required List<CartItem> cartItems,
    required Map<String, ProductCategory> productCategories,
    required ProductCategory category,
    required double subtotal,
    Map<String, double> drinkExtraPrices = const {},
  }) {
    final prices = <double>[];
    for (final item in cartItems) {
      final units = _unitCount(item);
      if (units <= 0) continue;
      if (_categoryOf(item, productCategories) == category) {
        for (var i = 0; i < units; i++) {
          prices.add(item.unitPrice);
        }
      }
      if (category != ProductCategory.drink) continue;
      for (final optionId in item.selectedOptions) {
        final extraPrice = drinkExtraPrices[optionId];
        if (extraPrice == null || extraPrice <= 0) continue;
        for (var i = 0; i < units; i++) {
          prices.add(extraPrice);
        }
      }
    }
    if (prices.isEmpty) return 0;
    prices.sort();
    final cheapest = prices.first;
    if (cheapest < 0) return 0;
    if (cheapest > subtotal) return subtotal;
    return cheapest;
  }

  static double _buyXGetYDiscount(
    PromotionCampaign campaign,
    List<CartItem> cartItems,
    Map<String, ProductCategory> productCategories,
    double subtotal,
  ) {
    if (campaign.buyQuantity <= 0 || campaign.freeQuantity <= 0) return 0;
    final bought = _conditionQuantity(campaign, cartItems, productCategories);
    final groups = bought ~/ campaign.buyQuantity;
    if (groups <= 0) return 0;
    final freeCount = groups * campaign.freeQuantity;
    return _cheapestUnits(
      _rewardLines(campaign, cartItems, productCategories),
      freeCount,
    ).clamp(0, subtotal);
  }

  static int _conditionQuantity(
    PromotionCampaign campaign,
    List<CartItem> cartItems,
    Map<String, ProductCategory> productCategories,
  ) {
    final lines = campaign.hasScope
        ? _matchingLines(campaign, cartItems, productCategories)
        : cartItems;
    return lines.fold<int>(0, (sum, item) => sum + _unitCount(item));
  }

  static List<CartItem> _rewardLines(
    PromotionCampaign campaign,
    List<CartItem> cartItems,
    Map<String, ProductCategory> productCategories,
  ) {
    if (campaign.rewardProductIds.isNotEmpty) {
      return cartItems
          .where((item) => campaign.rewardProductIds.contains(item.productId))
          .toList();
    }
    if (campaign.hasScope) {
      return _matchingLines(campaign, cartItems, productCategories);
    }
    return cartItems;
  }

  static List<CartItem> _matchingLines(
    PromotionCampaign campaign,
    List<CartItem> cartItems,
    Map<String, ProductCategory> productCategories,
  ) {
    return cartItems.where((item) {
      if (campaign.productIds.isNotEmpty) {
        return campaign.productIds.contains(item.productId);
      }
      final category = campaign.scopedCategory;
      if (category != null) {
        return productCategories[item.productId] == category;
      }
      return true;
    }).toList();
  }

  static int _unitCount(CartItem item) {
    final count = item.quantity.round();
    if (count > 0) return count;
    return item.quantity > 0 ? 1 : 0;
  }

  static double _cheapestUnits(List<CartItem> lines, int count) {
    if (count <= 0 || lines.isEmpty) return 0;
    final prices = <double>[];
    for (final item in lines) {
      final units = _unitCount(item);
      for (var i = 0; i < units; i++) {
        prices.add(item.unitPrice);
      }
    }
    prices.sort();
    final take = count > prices.length ? prices.length : count;
    var sum = 0.0;
    for (var i = 0; i < take; i++) {
      sum += prices[i];
    }
    return sum;
  }

  static PromotionCampaign? bestAutoPromotion({
    required List<PromotionCampaign> campaigns,
    required double subtotal,
    required List<CartItem> cartItems,
    required Map<String, ProductCategory> productCategories,
    double deliveryFee = 0,
    bool isFirstOrder = true,
    Map<String, double> drinkExtraPrices = const {},
  }) {
    PromotionCampaign? best;
    var bestDiscount = 0.0;

    for (final campaign in campaigns) {
      if (!campaign.isActive) continue;
      final freeDrinks = campaign.type == PromotionType.freeDrinks;
      if (!freeDrinks && (!campaign.autoApply || campaign.hasCode)) {
        continue;
      }
      final discount = discountFor(
        campaign: campaign,
        subtotal: subtotal,
        cartItems: cartItems,
        productCategories: productCategories,
        deliveryFee: deliveryFee,
        isFirstOrder: isFirstOrder,
        drinkExtraPrices: drinkExtraPrices,
      );
      if (discount > bestDiscount) {
        bestDiscount = discount;
        best = campaign;
      }
    }

    return bestDiscount > 0 ? best : null;
  }

  /// Anasayfadaki kampanyalı ürünler. Kapsamlı kampanya kendi ürünlerini,
  /// içecek kampanyası içecekleri döner. Kapsamsız kampanyada ürün listesi boştur.
  static List<Product> productsForCampaign(
    PromotionCampaign campaign,
    List<Product> catalog, {
    bool sahandaEnabled = true,
    int limit = 8,
  }) {
    final available = catalog.where((product) {
      if (!product.isAvailable) return false;
      if (!sahandaEnabled && product.category == ProductCategory.sahanda) {
        return false;
      }
      return true;
    });
    final ids = {...campaign.productIds, ...campaign.rewardProductIds};
    final Iterable<Product> matched;
    if (ids.isNotEmpty) {
      matched = available.where((product) => ids.contains(product.id));
    } else if (campaign.scopedCategory != null) {
      matched = available.where(
        (product) => product.category == campaign.scopedCategory,
      );
    } else if (campaign.type == PromotionType.freeDrinks) {
      matched = available.where(
        (product) => product.category == ProductCategory.drink,
      );
    } else {
      return const [];
    }
    return matched.take(limit).toList();
  }
}
