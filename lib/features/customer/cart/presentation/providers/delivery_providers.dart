import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/utils/delivery_eta_utils.dart';
import '../../../../../core/utils/delivery_fee_utils.dart';
import '../../../../../shared/presentation/providers/delivery_settings_provider.dart';
import '../../../checkout/presentation/providers/coupon_provider.dart';
import '../../../home/presentation/providers/branch_provider.dart';
import '../../../profile/presentation/providers/address_provider.dart';
import 'cart_provider.dart';

final deliveryFeeProvider = Provider<double>((ref) {
  final branch = ref.watch(branchProvider).value;
  if (branch == null) return 0;

  final subtotal = ref.watch(cartSubtotalProvider);
  final address = ref.watch(selectedCheckoutAddressProvider);
  final freeDeliveryMinOrder = ref.watch(effectiveFreeDeliveryMinOrderProvider);

  return DeliveryFeeUtils.calculate(
    branch: branch,
    subtotal: subtotal,
    deliveryLat: address?.latitude,
    deliveryLng: address?.longitude,
    freeDeliveryMinOrder: freeDeliveryMinOrder,
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

final checkoutEtaMinutesProvider = Provider<int>((ref) {
  final branch = ref.watch(branchProvider).value;
  if (branch == null) return 30;

  final address = ref.watch(selectedCheckoutAddressProvider);
  return DeliveryEtaUtils.estimateTotalMinutes(
    branch: branch,
    deliveryLat: address?.latitude,
    deliveryLng: address?.longitude,
  );
});
