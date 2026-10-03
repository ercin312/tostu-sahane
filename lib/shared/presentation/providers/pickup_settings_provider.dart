import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/pickup_settings.dart';
import 'repository_providers.dart';

final pickupSettingsProvider = StreamProvider<PickupSettings>((ref) {
  return ref.watch(adminRepositoryProvider).watchPickupSettings();
});

Future<void> savePickupSettings(WidgetRef ref, PickupSettings settings) {
  return ref.read(adminRepositoryProvider).updatePickupSettings(settings);
}
