import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/print_routing_settings.dart';
import 'repository_providers.dart';

final printRoutingSettingsProvider =
    StreamProvider<PrintRoutingSettings>((ref) {
  return ref.watch(adminRepositoryProvider).watchPrintRoutingSettings();
});

Future<void> savePrintRoutingSettings(
  WidgetRef ref,
  PrintRoutingSettings settings,
) async {
  await ref.read(adminRepositoryProvider).updatePrintRoutingSettings(settings);
}
