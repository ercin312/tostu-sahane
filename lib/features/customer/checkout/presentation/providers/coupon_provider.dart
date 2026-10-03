import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/promotion_utils.dart';
import '../../../../../shared/domain/entities/coupon.dart';
import '../../../../../shared/presentation/providers/repository_providers.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../../../shared/domain/entities/promotion_campaign.dart';
import '../../../../../shared/presentation/providers/pickup_settings_provider.dart';
import '../../../../../shared/presentation/providers/promotion_providers.dart';
import '../../../pickup/presentation/providers/fulfillment_mode_provider.dart';
import '../../../cart/presentation/providers/delivery_providers.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';

final checkoutCampaignsProvider = Provider<List<PromotionCampaign>>((ref) {
  if (ref.watch(customerPickupActiveProvider)) {
    return ref.watch(pickupSettingsProvider).valueOrNull?.activeCampaigns ??
        const [];
  }
  return ref.watch(activePromotionCampaignsProvider);
});

class CheckoutDiscountSelection {
  const CheckoutDiscountSelection({
    required this.label,
    required this.amount,
    this.code,
    this.campaignId,
    this.isAuto = false,
    this.isPromotion = false,
  });

  final String label;
  final double amount;
  final String? code;
  final String? campaignId;
  final bool isAuto;
  final bool isPromotion;
}

final appliedCheckoutDiscountProvider =
    StateProvider<CheckoutDiscountSelection?>((ref) => null);

final autoCheckoutDiscountProvider = Provider<CheckoutDiscountSelection?>((ref) {
  if (ref.watch(appliedCheckoutDiscountProvider) != null) return null;

  final subtotal = ref.watch(cartSubtotalProvider);
  final cart = ref.watch(cartProvider);
  final categories = ref.watch(productCategoryMapProvider);
  final drinkExtras = ref.watch(drinkExtraPricesProvider);
  final campaigns = ref.watch(checkoutCampaignsProvider);

  final deliveryFee = ref.watch(deliveryFeeProvider);
  final isFirstOrder = ref.watch(customerIsFirstOrderProvider);
  final best = PromotionUtils.bestAutoPromotion(
    campaigns: campaigns,
    subtotal: subtotal,
    cartItems: cart,
    productCategories: categories,
    deliveryFee: deliveryFee,
    isFirstOrder: isFirstOrder,
    drinkExtraPrices: drinkExtras,
  );
  if (best == null) return null;

  final amount = PromotionUtils.discountFor(
    campaign: best,
    subtotal: subtotal,
    cartItems: cart,
    productCategories: categories,
    deliveryFee: deliveryFee,
    isFirstOrder: isFirstOrder,
    drinkExtraPrices: drinkExtras,
  );
  if (amount <= 0) return null;

  return CheckoutDiscountSelection(
    label: best.title,
    amount: amount,
    code: best.hasCode ? best.normalizedCode : null,
    isAuto: true,
    isPromotion: true,
  );
});

final checkoutDiscountProvider = Provider<double>((ref) {
  final manual = ref.watch(appliedCheckoutDiscountProvider);
  if (manual?.campaignId != null) {
    final campaigns = ref.watch(checkoutCampaignsProvider);
    PromotionCampaign? campaign;
    for (final item in campaigns) {
      if (item.id == manual!.campaignId) {
        campaign = item;
        break;
      }
    }
    if (campaign == null) return 0;
    return PromotionUtils.discountFor(
      campaign: campaign,
      subtotal: ref.watch(cartSubtotalProvider),
      cartItems: ref.watch(cartProvider),
      productCategories: ref.watch(productCategoryMapProvider),
      deliveryFee: ref.watch(deliveryFeeProvider),
      isFirstOrder: ref.watch(customerIsFirstOrderProvider),
      drinkExtraPrices: ref.watch(drinkExtraPricesProvider),
    );
  }
  if (manual != null) return manual.amount;
  return ref.watch(autoCheckoutDiscountProvider)?.amount ?? 0;
});

final checkoutDiscountLabelProvider = Provider<String?>((ref) {
  final manual = ref.watch(appliedCheckoutDiscountProvider);
  if (manual != null) return manual.label;
  return ref.watch(autoCheckoutDiscountProvider)?.label;
});

final checkoutDiscountCodeProvider = Provider<String?>((ref) {
  final manual = ref.watch(appliedCheckoutDiscountProvider);
  if (manual != null) return manual.code;
  return ref.watch(autoCheckoutDiscountProvider)?.code;
});

final couponDiscountProvider = checkoutDiscountProvider;

final appliedCouponProvider = Provider<Coupon?>((ref) => null);

final couponNotifierProvider =
    Provider<CouponNotifier>((ref) => CouponNotifier(ref));

class CouponNotifier {
  CouponNotifier(this._ref);

  final Ref _ref;

  Future<String?> apply(String code) async {
    final normalized = code.trim();
    if (normalized.isEmpty) return 'coupon_empty';

    final subtotal = _ref.read(cartSubtotalProvider);
    final cart = _ref.read(cartProvider);
    final categories = _ref.read(productCategoryMapProvider);
    final drinkExtras = _ref.read(drinkExtraPricesProvider);

    PromotionCampaign? promotion;
    if (_ref.read(customerPickupActiveProvider)) {
      final normalizedCode = normalized.toUpperCase();
      for (final item
          in _ref.read(pickupSettingsProvider).valueOrNull?.activeCampaigns ??
              const <PromotionCampaign>[]) {
        if (item.normalizedCode == normalizedCode) {
          promotion = item;
          break;
        }
      }
    } else {
      promotion = await _ref
          .read(promotionRepositoryProvider)
          .getPromotionByCode(normalized);
    }
    if (promotion != null) {
      final discount = PromotionUtils.discountFor(
        campaign: promotion,
        subtotal: subtotal,
        cartItems: cart,
        productCategories: categories,
        deliveryFee: _ref.read(deliveryFeeProvider),
        isFirstOrder: _ref.read(customerIsFirstOrderProvider),
        drinkExtraPrices: drinkExtras,
      );
      if (discount <= 0) return 'coupon_min_order';
      _ref.read(appliedCheckoutDiscountProvider.notifier).state =
          CheckoutDiscountSelection(
        label: promotion.title,
        amount: discount,
        code: promotion.hasCode ? promotion.normalizedCode : null,
        campaignId: promotion.id,
        isPromotion: true,
      );
      return null;
    }

    final coupon =
        await _ref.read(couponRepositoryProvider).getCoupon(normalized);
    if (coupon == null) return 'coupon_invalid';
    final discount = coupon.discountFor(subtotal);
    if (discount <= 0) return 'coupon_min_order';
    _ref.read(appliedCheckoutDiscountProvider.notifier).state =
        CheckoutDiscountSelection(
      label: coupon.code,
      amount: discount,
      code: coupon.code,
      isPromotion: false,
    );
    return null;
  }

  void applyCampaign(PromotionCampaign campaign) {
    final subtotal = _ref.read(cartSubtotalProvider);
    final cart = _ref.read(cartProvider);
    final categories = _ref.read(productCategoryMapProvider);
    final drinkExtras = _ref.read(drinkExtraPricesProvider);
    final discount = PromotionUtils.discountFor(
      campaign: campaign,
      subtotal: subtotal,
      cartItems: cart,
      productCategories: categories,
      deliveryFee: _ref.read(deliveryFeeProvider),
      isFirstOrder: _ref.read(customerIsFirstOrderProvider),
      drinkExtraPrices: drinkExtras,
    );
    _ref.read(appliedCheckoutDiscountProvider.notifier).state =
        CheckoutDiscountSelection(
      label: campaign.title,
      amount: discount,
      code: campaign.hasCode ? campaign.normalizedCode : null,
      campaignId: campaign.id,
      isPromotion: true,
    );
  }

  void clear() {
    _ref.read(appliedCheckoutDiscountProvider.notifier).state = null;
  }
}
