import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../../shared/domain/entities/pickup_settings.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/presentation/providers/pickup_settings_provider.dart';

enum CustomerFulfillment { delivery, pickup }

class FulfillmentModeNotifier extends Notifier<CustomerFulfillment> {
  static const _storageKey = 'customer_fulfillment_v1';

  @override
  CustomerFulfillment build() {
    Future.microtask(_forgetStoredPickup);
    return CustomerFulfillment.delivery;
  }

  /// Gel Al ayrı bir bölüm. Uygulama açılınca teslimat modunda başlanır.
  Future<void> _forgetStoredPickup() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_storageKey) == CustomerFulfillment.pickup.name) {
      await prefs.remove(_storageKey);
    }
  }

  void set(CustomerFulfillment mode) {
    state = mode;
  }
}

final fulfillmentModeProvider =
    NotifierProvider<FulfillmentModeNotifier, CustomerFulfillment>(
  FulfillmentModeNotifier.new,
);

/// Gel Al menüsü ve ödemesi yalnızca yönetici açıkken ve müşteri seçince geçerlidir.
final customerPickupActiveProvider = Provider<bool>((ref) {
  if (ref.watch(fulfillmentModeProvider) != CustomerFulfillment.pickup) {
    return false;
  }
  final settings = ref.watch(pickupSettingsProvider).valueOrNull;
  return settings?.enabled ?? false;
});

double customerUnitPrice({
  required Product product,
  required bool pickupActive,
  PickupSettings? settings,
}) {
  if (!pickupActive || settings == null || !settings.enabled) {
    return product.price;
  }
  return settings.priceFor(product.id, product.price);
}
