import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cashier_printer_settings.dart';

class CashierPrinterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  Future<void> load() async {
    state = await CashierPrinterSettings.load();
  }

  Future<void> save(String? printerName) async {
    await CashierPrinterSettings.save(printerName);
    state = printerName;
  }
}

final cashierPrinterProvider =
    NotifierProvider<CashierPrinterNotifier, String?>(CashierPrinterNotifier.new);
