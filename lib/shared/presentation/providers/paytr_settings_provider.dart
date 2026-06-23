import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/paytr_settings.dart';
import 'repository_providers.dart';

final paytrSettingsProvider = StreamProvider<PaytrSettings>((ref) {
  return ref.watch(adminRepositoryProvider).watchPaytrSettings();
});

final paytrEnabledProvider = Provider<bool>((ref) {
  final settings = ref.watch(paytrSettingsProvider).valueOrNull;
  return settings?.isConfigured ?? false;
});

Future<void> savePaytrSettings(WidgetRef ref, PaytrSettings settings) async {
  await ref.read(adminRepositoryProvider).updatePaytrSettings(settings);
}
