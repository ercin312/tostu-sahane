import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/payments/paytr_vat_utils.dart';
import '../../../features/customer/cart/presentation/providers/delivery_providers.dart';
import '../../domain/entities/paytr_settings.dart';
import 'paytr_settings_provider.dart';

final checkoutPayableTotalProvider = Provider<double>((ref) {
  final base = ref.watch(checkoutTotalProvider);
  final settings =
      ref.watch(paytrSettingsProvider).valueOrNull ?? PaytrSettings.defaults;
  return PaytrVatUtils.payableTotal(base, settings);
});

final checkoutVatAmountProvider = Provider<double>((ref) {
  final base = ref.watch(checkoutTotalProvider);
  final settings =
      ref.watch(paytrSettingsProvider).valueOrNull ?? PaytrSettings.defaults;
  return PaytrVatUtils.vatAmount(base, settings);
});

final checkoutShowsVatLineProvider = Provider<bool>((ref) {
  final settings = ref.watch(paytrSettingsProvider).valueOrNull;
  return settings?.isConfigured == true && settings!.vatRatePercent > 0;
});
