import 'waiter_preparation_option.dart';

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
    this.preparationOptions = defaultPreparationOptions,
    this.productDisplayOrder = const [],
    this.catalogExtraDisplayOrder = const [],
  });

  static const defaultPreparationOptions = [
    WaiterPreparationOption(
      id: 'mild_spicy',
      labelTr: 'Az acılı',
      labelEn: 'Mild spicy',
      sortOrder: 0,
    ),
    WaiterPreparationOption(
      id: 'spicy',
      labelTr: 'Acılı',
      labelEn: 'Spicy',
      sortOrder: 1,
    ),
    WaiterPreparationOption(
      id: 'less_cheese',
      labelTr: 'Az peynirli',
      labelEn: 'Less cheese',
      sortOrder: 2,
    ),
    WaiterPreparationOption(
      id: 'no_oil',
      labelTr: 'Yağsız',
      labelEn: 'No oil',
      sortOrder: 3,
    ),
    WaiterPreparationOption(
      id: 'less_sauce',
      labelTr: 'Az soslu',
      labelEn: 'Less sauce',
      sortOrder: 4,
    ),
  ];

  /// Garson / QR masa sayısı üst sınırı.
  static const maxTableCount = 200;

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
  final List<WaiterPreparationOption> preparationOptions;
  final List<String> productDisplayOrder;
  final List<String> catalogExtraDisplayOrder;

  static const defaults = WaiterModeSettings();

  String get posBaseUrl {
    final host = posHost.trim();
    if (host.isEmpty) return '';
    return 'http://$host:$posPort';
  }

  List<WaiterPreparationOption> get enabledPreparationOptions {
    return preparationOptions
        .where((o) => o.enabled)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
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
    List<WaiterPreparationOption>? preparationOptions,
    List<String>? productDisplayOrder,
    List<String>? catalogExtraDisplayOrder,
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
      preparationOptions: preparationOptions ?? this.preparationOptions,
      productDisplayOrder: productDisplayOrder ?? this.productDisplayOrder,
      catalogExtraDisplayOrder:
          catalogExtraDisplayOrder ?? this.catalogExtraDisplayOrder,
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
        'preparation_options':
            preparationOptions.map((e) => e.toJson()).toList(),
        'product_display_order': productDisplayOrder,
        'catalog_extra_display_order': catalogExtraDisplayOrder,
      };

  static Map<String, double> _readPriceMap(dynamic raw) {
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString(): (entry.value as num).toDouble(),
    };
  }

  static List<String> _readStringList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.map((e) => e.toString()).toList();
  }

  static List<WaiterPreparationOption> _readPreparationOptions(dynamic raw) {
    if (raw is! List || raw.isEmpty) return defaultPreparationOptions;
    return raw
        .map(
          (e) => WaiterPreparationOption.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
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
      preparationOptions: _readPreparationOptions(json['preparation_options']),
      productDisplayOrder: _readStringList(json['product_display_order']),
      catalogExtraDisplayOrder:
          _readStringList(json['catalog_extra_display_order']),
    );
  }
}
