import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/promotion_utils.dart';
import '../../../../../shared/domain/entities/coupon.dart';
import '../../../../../shared/presentation/providers/repository_providers.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../../../shared/presentation/providers/promotion_providers.dart';

class CheckoutDiscountSelection {
  const CheckoutDiscountSelection({
    required this.label,
    required this.amount,
    this.code,
    this.isAuto = false,
    this.isPromotion = false,
  });

  final String label;
  final double amount;
  final String? code;
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
  final campaigns = ref.watch(activePromotionCampaignsProvider);

  final best = PromotionUtils.bestAutoPromotion(
    campaigns: campaigns,
    subtotal: subtotal,
    cartItems: cart,
    productCategories: categories,
  );
  if (best == null) return null;

  final amount = PromotionUtils.discountFor(
    campaign: best,
    subtotal: subtotal,
    cartItems: cart,
    productCategories: categories,
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

    final promotion = await _ref
        .read(promotionRepositoryProvider)
        .getPromotionByCode(normalized);
    if (promotion != null) {
      final discount = PromotionUtils.discountFor(
        campaign: promotion,
        subtotal: subtotal,
        cartItems: cart,
        productCategories: categories,
      );
      if (discount <= 0) return 'coupon_min_order';
      _ref.read(appliedCheckoutDiscountProvider.notifier).state =
          CheckoutDiscountSelection(
        label: promotion.title,
        amount: discount,
        code: promotion.normalizedCode,
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

  void clear() {
    _ref.read(appliedCheckoutDiscountProvider.notifier).state = null;
  }
}
