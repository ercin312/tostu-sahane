import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/delivery_eta_utils.dart';
import '../../../../../core/utils/delivery_fee_utils.dart';
import '../../../../../shared/domain/entities/delivery_settings.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../../../../shared/presentation/providers/delivery_settings_provider.dart';
import '../../../../../shared/presentation/providers/pickup_settings_provider.dart';
import '../../../checkout/presentation/providers/coupon_provider.dart';
import '../../../home/presentation/providers/branch_provider.dart';
import '../../../pickup/presentation/providers/fulfillment_mode_provider.dart';
import '../../../profile/presentation/providers/address_provider.dart';
import 'cart_provider.dart';

/// Admin seçimi. Sepette olan ve kapalı ürünler listeden düşer.
final cartUpsellProductsProvider = Provider<List<Product>>((ref) {
  final ids = ref.watch(deliverySettingsProvider).valueOrNull?.upsellProductIds ??
      const <String>[];
  if (ids.isEmpty) return const [];

  final products = ref.watch(productsProvider).value ?? const <Product>[];
  final sahandaEnabled =
      ref.watch(waiterModeSettingsProvider).valueOrNull?.customerSahandaEnabled ??
          true;
  final inCart = ref.watch(cartProvider).map((item) => item.productId).toSet();
  final byId = {for (final product in products) product.id: product};

  return [
    for (final id in ids)
      if (byId[id] case final product?)
        if (product.isAvailable &&
            !inCart.contains(product.id) &&
            (sahandaEnabled || product.category != ProductCategory.sahanda))
          product,
  ];
});

final deliveryFeeProvider = Provider<double>((ref) {
  if (ref.watch(customerPickupActiveProvider)) return 0;
  final branch = ref.watch(branchProvider).value;
  if (branch == null) return 0;

  final subtotal = ref.watch(cartSubtotalProvider);
  final address = ref.watch(selectedCheckoutAddressProvider);
  final settings =
      ref.watch(deliverySettingsProvider).valueOrNull ?? DeliverySettings.defaults;

  return DeliveryFeeUtils.calculate(
    branch: branch,
    subtotal: subtotal,
    deliveryLat: address?.latitude,
    deliveryLng: address?.longitude,
    freeDeliveryMinOrder: settings.freeDeliveryMinOrder,
    belowMinimumDeliveryFee: settings.belowMinimumDeliveryFee,
  );
});

final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartSubtotalProvider) + ref.watch(deliveryFeeProvider);
});

final checkoutTotalProvider = Provider<double>((ref) {
  final total = ref.watch(cartTotalProvider);
  final discount = ref.watch(checkoutDiscountProvider);
  return (total - discount).clamp(0, double.infinity);
});

final cartMeetsMinimumProvider = Provider<bool>((ref) {
  if (!ref.watch(customerPickupActiveProvider)) return true;
  return ref.watch(cartSubtotalProvider) >=
      ref.watch(effectiveMinimumOrderProvider);
});

final effectiveMinimumOrderProvider = Provider<double>((ref) {
  if (!ref.watch(customerPickupActiveProvider)) {
    return ref.watch(effectiveFreeDeliveryMinOrderProvider);
  }
  return ref.watch(pickupSettingsProvider).valueOrNull?.minOrderAmount ?? 0;
});

final checkoutEtaMinutesProvider = Provider<int>((ref) {
  if (ref.watch(customerPickupActiveProvider)) {
    return ref.watch(pickupSettingsProvider).valueOrNull?.readyMinutes ?? 15;
  }
  final branch = ref.watch(branchProvider).value;
  if (branch == null) return 30;

  final address = ref.watch(selectedCheckoutAddressProvider);
  return DeliveryEtaUtils.estimateTotalMinutes(
    branch: branch,
    deliveryLat: address?.latitude,
    deliveryLng: address?.longitude,
  );
});
