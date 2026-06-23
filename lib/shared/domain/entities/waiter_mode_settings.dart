class WaiterModeSettings {
  const WaiterModeSettings({
    this.tableCount = 24,
    this.customerSahandaEnabled = true,
    this.printKitchenReceiptOnWaiterOrder = true,
    this.posEnabled = false,
    this.posHost = '',
    this.posPort = 4568,
    this.posSerialNumber = '',
    this.posSalePath = '/Payment/CardPayment',
    this.productPrices = const {},
    this.catalogExtraPrices = const {},
  });

  final int tableCount;
  final bool customerSahandaEnabled;
  /// Garson modundan iç sipariş girildiğinde mutfak fişi otomatik yazdırılsın mı?
  final bool printKitchenReceiptOnWaiterOrder;
  final bool posEnabled;
  final String posHost;
  final int posPort;
  final String posSerialNumber;
  final String posSalePath;
  /// Garson modu menü ürün fiyatları (ürün id → fiyat). Boşsa mobil menü fiyatı kullanılır.
  final Map<String, double> productPrices;
  /// Garson modu içecek/aparatif fiyatları (katalog ekstra id → fiyat).
  final Map<String, double> catalogExtraPrices;

  static const defaults = WaiterModeSettings();

  String get posBaseUrl {
    final host = posHost.trim();
    if (host.isEmpty) return '';
    return 'http://$host:$posPort';
  }

  WaiterModeSettings copyWith({
    int? tableCount,
    bool? customerSahandaEnabled,
    bool? printKitchenReceiptOnWaiterOrder,
    bool? posEnabled,
    String? posHost,
    int? posPort,
    String? posSerialNumber,
    String? posSalePath,
    Map<String, double>? productPrices,
    Map<String, double>? catalogExtraPrices,
  }) {
    return WaiterModeSettings(
      tableCount: tableCount ?? this.tableCount,
      customerSahandaEnabled:
          customerSahandaEnabled ?? this.customerSahandaEnabled,
      printKitchenReceiptOnWaiterOrder: printKitchenReceiptOnWaiterOrder ??
          this.printKitchenReceiptOnWaiterOrder,
      posEnabled: posEnabled ?? this.posEnabled,
      posHost: posHost ?? this.posHost,
      posPort: posPort ?? this.posPort,
      posSerialNumber: posSerialNumber ?? this.posSerialNumber,
      posSalePath: posSalePath ?? this.posSalePath,
      productPrices: productPrices ?? this.productPrices,
      catalogExtraPrices: catalogExtraPrices ?? this.catalogExtraPrices,
    );
  }

  Map<String, dynamic> toJson() => {
        'table_count': tableCount,
        'customer_sahanda_enabled': customerSahandaEnabled,
        'print_kitchen_receipt_on_waiter_order':
            printKitchenReceiptOnWaiterOrder,
        'pos_enabled': posEnabled,
        'pos_host': posHost,
        'pos_port': posPort,
        'pos_serial_number': posSerialNumber,
        'pos_sale_path': posSalePath,
        'product_prices': productPrices,
        'catalog_extra_prices': catalogExtraPrices,
      };

  static Map<String, double> _readPriceMap(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): (entry.value as num).toDouble(),
    };
  }

  factory WaiterModeSettings.fromJson(Map<String, dynamic> json) {
    return WaiterModeSettings(
      tableCount: (json['table_count'] as num?)?.toInt() ?? 24,
      customerSahandaEnabled: json['customer_sahanda_enabled'] as bool? ?? true,
      printKitchenReceiptOnWaiterOrder:
          json['print_kitchen_receipt_on_waiter_order'] as bool? ?? true,
      posEnabled: json['pos_enabled'] as bool? ?? false,
      posHost: json['pos_host'] as String? ?? '',
      posPort: (json['pos_port'] as num?)?.toInt() ?? 4568,
      posSerialNumber: json['pos_serial_number'] as String? ?? '',
      posSalePath:
          json['pos_sale_path'] as String? ?? '/Payment/CardPayment',
      productPrices: _readPriceMap(json['product_prices']),
      catalogExtraPrices: _readPriceMap(json['catalog_extra_prices']),
    );
  }
}
