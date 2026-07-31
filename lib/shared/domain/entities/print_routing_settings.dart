/// Hangi bölümde hangi sipariş tipinin hangi yazıcıdan otomatik çıkacağı.
enum PhoneOrderPrinterTarget { kitchen, cashier }

class PrintRoutingSettings {
  const PrintRoutingSettings({
    this.dineInAtKitchen = true,
    this.dineInAtCashier = false,
    this.deliveryAtKitchen = true,
    this.deliveryAtCashier = true,
    this.phoneOrderPrinter = PhoneOrderPrinterTarget.kitchen,
    this.kitchenPrinterName = '',
    this.cashierPrinterName = '',
  });

  /// Mutfak ekranı (kitchenStaff) — iç sipariş fişi.
  final bool dineInAtKitchen;

  /// Kasa / şube paneli (branchManager, branchStaff) — iç sipariş fişi.
  final bool dineInAtCashier;

  /// Mutfak ekranı — paket servis (yeni) fişi.
  final bool deliveryAtKitchen;

  /// Kasa / şube paneli — paket servis (yeni) fişi.
  final bool deliveryAtCashier;

  /// Telefon AI siparişlerinin basılacağı yazıcı (mutfak veya kasa).
  final PhoneOrderPrinterTarget phoneOrderPrinter;

  /// Boşsa ilgili cihazın yerel yazıcı seçimi kullanılır.
  final String kitchenPrinterName;
  final String cashierPrinterName;

  static const defaults = PrintRoutingSettings();

  PrintRoutingSettings copyWith({
    bool? dineInAtKitchen,
    bool? dineInAtCashier,
    bool? deliveryAtKitchen,
    bool? deliveryAtCashier,
    PhoneOrderPrinterTarget? phoneOrderPrinter,
    String? kitchenPrinterName,
    String? cashierPrinterName,
  }) {
    return PrintRoutingSettings(
      dineInAtKitchen: dineInAtKitchen ?? this.dineInAtKitchen,
      dineInAtCashier: dineInAtCashier ?? this.dineInAtCashier,
      deliveryAtKitchen: deliveryAtKitchen ?? this.deliveryAtKitchen,
      deliveryAtCashier: deliveryAtCashier ?? this.deliveryAtCashier,
      phoneOrderPrinter: phoneOrderPrinter ?? this.phoneOrderPrinter,
      kitchenPrinterName: kitchenPrinterName ?? this.kitchenPrinterName,
      cashierPrinterName: cashierPrinterName ?? this.cashierPrinterName,
    );
  }

  Map<String, dynamic> toJson() => {
        'dine_in_at_kitchen': dineInAtKitchen,
        'dine_in_at_cashier': dineInAtCashier,
        'delivery_at_kitchen': deliveryAtKitchen,
        'delivery_at_cashier': deliveryAtCashier,
        'phone_order_printer': phoneOrderPrinter.name,
        'kitchen_printer_name': kitchenPrinterName,
        'cashier_printer_name': cashierPrinterName,
      };

  factory PrintRoutingSettings.fromJson(Map<String, dynamic> json) {
    final phoneRaw = json['phone_order_printer'] as String?;
    final phoneTarget = PhoneOrderPrinterTarget.values.asNameMap()[phoneRaw] ??
        PhoneOrderPrinterTarget.kitchen;
    return PrintRoutingSettings(
      dineInAtKitchen: json['dine_in_at_kitchen'] as bool? ?? true,
      dineInAtCashier: json['dine_in_at_cashier'] as bool? ?? false,
      deliveryAtKitchen: json['delivery_at_kitchen'] as bool? ?? true,
      deliveryAtCashier: json['delivery_at_cashier'] as bool? ?? true,
      phoneOrderPrinter: phoneTarget,
      kitchenPrinterName: json['kitchen_printer_name'] as String? ?? '',
      cashierPrinterName: json['cashier_printer_name'] as String? ?? '',
    );
  }
}
