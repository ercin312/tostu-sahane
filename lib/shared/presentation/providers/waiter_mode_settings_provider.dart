import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/waiter_mode_settings.dart';
import 'repository_providers.dart';

final waiterModeSettingsProvider = StreamProvider<WaiterModeSettings>((ref) {
  return ref.watch(adminRepositoryProvider).watchWaiterModeSettings();
});

Future<void> saveWaiterModeSettings(
  WidgetRef ref,
  WaiterModeSettings settings,
) async {
  await ref.read(adminRepositoryProvider).updateWaiterModeSettings(settings);
}
