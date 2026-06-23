import '../../shared/domain/entities/order.dart';
import '../../shared/domain/entities/product.dart';
import '../../shared/domain/entities/promotion_campaign.dart';

abstract final class PromotionUtils {
  static bool isEligible({
    required PromotionCampaign campaign,
    required double subtotal,
  }) {
    if (!campaign.isActive) return false;
    return subtotal >= campaign.minOrderAmount;
  }

  static double discountFor({
    required PromotionCampaign campaign,
    required double subtotal,
    required List<CartItem> cartItems,
    required Map<String, ProductCategory> productCategories,
  }) {
    if (!isEligible(campaign: campaign, subtotal: subtotal)) return 0;

    return switch (campaign.type) {
      PromotionType.percentDiscount =>
        subtotal * (campaign.value.clamp(0, 100) / 100),
      PromotionType.fixedDiscount =>
        campaign.value.clamp(0, subtotal),
      PromotionType.freeDrinks => _freeCategoryDiscount(
          cartItems: cartItems,
          productCategories: productCategories,
          category: ProductCategory.drink,
          subtotal: subtotal,
        ),
    };
  }

  static double _freeCategoryDiscount({
    required List<CartItem> cartItems,
    required Map<String, ProductCategory> productCategories,
    required ProductCategory category,
    required double subtotal,
  }) {
    var discount = 0.0;
    for (final item in cartItems) {
      if (productCategories[item.productId] == category) {
        discount += item.totalPrice;
      }
    }
    return discount.clamp(0, subtotal);
  }

  static PromotionCampaign? bestAutoPromotion({
    required List<PromotionCampaign> campaigns,
    required double subtotal,
    required List<CartItem> cartItems,
    required Map<String, ProductCategory> productCategories,
  }) {
    PromotionCampaign? best;
    var bestDiscount = 0.0;

    for (final campaign in campaigns) {
      if (!campaign.isActive || !campaign.autoApply || campaign.hasCode) {
        continue;
      }
      final discount = discountFor(
        campaign: campaign,
        subtotal: subtotal,
        cartItems: cartItems,
        productCategories: productCategories,
      );
      if (discount > bestDiscount) {
        bestDiscount = discount;
        best = campaign;
      }
    }

    return bestDiscount > 0 ? best : null;
  }
}
