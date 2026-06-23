import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/delivery_settings.dart';
import 'repository_providers.dart';

final deliverySettingsProvider = StreamProvider<DeliverySettings>((ref) {
  return ref.watch(adminRepositoryProvider).watchDeliverySettings();
});

final effectiveFreeDeliveryMinOrderProvider = Provider<double>((ref) {
  final settings =
      ref.watch(deliverySettingsProvider).valueOrNull ?? DeliverySettings.defaults;
  return settings.freeDeliveryMinOrder;
});

Future<void> saveDeliverySettings(
  WidgetRef ref,
  DeliverySettings settings,
) async {
  await ref.read(adminRepositoryProvider).updateDeliverySettings(settings);
}
