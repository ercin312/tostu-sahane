import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kitchen_printer_settings.dart';

class KitchenPrinterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  Future<void> load() async {
    state = await KitchenPrinterSettings.load();
  }

  Future<void> save(String? printerName) async {
    await KitchenPrinterSettings.save(printerName);
    state = printerName;
  }
}

final kitchenPrinterProvider =
    NotifierProvider<KitchenPrinterNotifier, String?>(KitchenPrinterNotifier.new);
