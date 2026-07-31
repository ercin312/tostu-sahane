import 'package:equatable/equatable.dart';

enum TableServiceRequestType { callWaiter, requestBill }

enum TableServiceRequestStatus { pending, acked, done }

class TableServiceRequest extends Equatable {
  const TableServiceRequest({
    required this.id,
    required this.branchId,
    required this.tableNumber,
    required this.type,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String branchId;
  final int tableNumber;
  final TableServiceRequestType type;
  final TableServiceRequestStatus status;
  final String message;
  final DateTime createdAt;

  bool get isPending => status == TableServiceRequestStatus.pending;

  factory TableServiceRequest.fromJson(String id, Map<String, dynamic> json) {
    final typeRaw = json['type'] as String? ?? 'call_waiter';
    final statusRaw = json['status'] as String? ?? 'pending';
    DateTime created;
    final rawCreated = json['created_at'];
    if (rawCreated is String) {
      created = DateTime.tryParse(rawCreated) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }
    return TableServiceRequest(
      id: id,
      branchId: json['branch_id'] as String? ?? '',
      tableNumber: (json['table_number'] as num?)?.toInt() ?? 0,
      type: typeRaw == 'request_bill'
          ? TableServiceRequestType.requestBill
          : TableServiceRequestType.callWaiter,
      status: switch (statusRaw) {
        'acked' => TableServiceRequestStatus.acked,
        'done' => TableServiceRequestStatus.done,
        _ => TableServiceRequestStatus.pending,
      },
      message: json['message'] as String? ?? '',
      createdAt: created,
    );
  }

  Map<String, dynamic> toJson() => {
        'branch_id': branchId,
        'table_number': tableNumber,
        'type': type == TableServiceRequestType.requestBill
            ? 'request_bill'
            : 'call_waiter',
        'status': switch (status) {
          TableServiceRequestStatus.acked => 'acked',
          TableServiceRequestStatus.done => 'done',
          _ => 'pending',
        },
        'message': message,
        'created_at': createdAt.toIso8601String(),
      };

  @override
  List<Object?> get props =>
      [id, branchId, tableNumber, type, status, message, createdAt];
}

/// QR menü üst navbar kategorisi (yönetici ekler/siler).
class QrNavCategory extends Equatable {
  const QrNavCategory({
    required this.id,
    required this.label,
    this.enabled = true,
    this.sortOrder = 0,
  });

  final String id;
  final String label;
  final bool enabled;
  final int sortOrder;

  factory QrNavCategory.fromJson(Map<String, dynamic> json) => QrNavCategory(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ??
            json['label_tr']?.toString() ??
            '',
        enabled: json['enabled'] != false,
        sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'label_tr': label,
        'enabled': enabled,
        'sort_order': sortOrder,
      };

  QrNavCategory copyWith({
    String? id,
    String? label,
    bool? enabled,
    int? sortOrder,
  }) {
    return QrNavCategory(
      id: id ?? this.id,
      label: label ?? this.label,
      enabled: enabled ?? this.enabled,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  List<Object?> get props => [id, label, enabled, sortOrder];
}

class QrMenuSettings extends Equatable {
  const QrMenuSettings({
    this.enabled = true,
    this.title = 'Tost-u Şahane',
    this.welcomeNote = 'Lezzetler sofranıza gelsin.',
    this.baseUrl = defaultBaseUrl,
    this.defaultBranchId = 'branch_1',
    this.hiddenProductIds = const [],
    this.featuredProductIds = const [],
    this.productDisplayOrder = const [],
    this.navCategories = const [
      QrNavCategory(id: 'tost', label: 'Tostlar', sortOrder: 0),
      QrNavCategory(id: 'sahanda', label: 'Sahandakiler', sortOrder: 1),
      QrNavCategory(id: 'drink', label: 'İçecekler', sortOrder: 2),
      QrNavCategory(id: 'snack', label: 'Atıştırmalık', sortOrder: 3),
      QrNavCategory(id: 'extra', label: 'Ekstralar', sortOrder: 4),
    ],
  });

  final bool enabled;
  final String title;
  final String welcomeNote;
  final String baseUrl;
  final String defaultBranchId;
  final List<String> hiddenProductIds;
  final List<String> featuredProductIds;
  final List<String> productDisplayOrder;
  final List<QrNavCategory> navCategories;

  static const defaultBaseUrl = 'https://www.tostusahane.com/qr/';
  static const defaults = QrMenuSettings();

  static String normalizeBaseUrl(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return defaultBaseUrl;
    final stripped = v.replaceAll(RegExp(r'/+$'), '');
    if (stripped == 'https://tostusahane.alanyaproje.com' ||
        stripped == 'http://tostusahane.alanyaproje.com') {
      return defaultBaseUrl;
    }
    return v;
  }

  List<QrNavCategory> get enabledNavCategories {
    final list = navCategories.where((c) => c.enabled && c.id.isNotEmpty).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  /// Eski `categories` map uyumu (web / eski okuyucular).
  Map<String, bool> get categories => {
        for (final c in navCategories) c.id: c.enabled,
      };

  Map<String, String> get categoryLabels => {
        for (final c in navCategories) c.id: c.label,
      };

  String tableUrl(int tableNumber) {
    final base = baseUrl.replaceAll(RegExp(r'/$'), '');
    return '$base/?table=$tableNumber&branch=$defaultBranchId';
  }

  factory QrMenuSettings.fromJson(Map<String, dynamic> json) {
    final navRaw = json['nav_categories'];
    var nav = <QrNavCategory>[];
    if (navRaw is List && navRaw.isNotEmpty) {
      for (var i = 0; i < navRaw.length; i++) {
        final e = navRaw[i];
        if (e is Map) {
          final cat = QrNavCategory.fromJson(Map<String, dynamic>.from(e));
          if (cat.id.isEmpty) continue;
          nav.add(
            cat.sortOrder == 0 && i > 0 ? cat.copyWith(sortOrder: i) : cat,
          );
        }
      }
    }

    // Eski format: categories map
    if (nav.isEmpty) {
      final catsRaw = json['categories'];
      if (catsRaw is Map) {
        var i = 0;
        catsRaw.forEach((key, value) {
          final k = key.toString();
          var enabled = true;
          var label = k;
          if (value is Map) {
            enabled = value['enabled'] != false;
            label = (value['label_tr'] ?? value['label'] ?? k).toString();
          } else if (value is bool) {
            enabled = value;
          }
          nav.add(
            QrNavCategory(
              id: k,
              label: label,
              enabled: enabled,
              sortOrder: i++,
            ),
          );
        });
      }
    }

    if (nav.isEmpty) {
      nav = List<QrNavCategory>.from(defaults.navCategories);
    }

    return QrMenuSettings(
      enabled: json['enabled'] as bool? ?? true,
      title: json['title'] as String? ?? defaults.title,
      welcomeNote: json['welcome_note'] as String? ?? defaults.welcomeNote,
      baseUrl: normalizeBaseUrl(json['base_url'] as String?),
      defaultBranchId:
          json['default_branch_id'] as String? ?? defaults.defaultBranchId,
      hiddenProductIds: (json['hidden_product_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      featuredProductIds: (json['featured_product_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      productDisplayOrder: (json['product_display_order'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      navCategories: nav,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'title': title,
        'welcome_note': welcomeNote,
        'base_url': baseUrl,
        'default_branch_id': defaultBranchId,
        'hidden_product_ids': hiddenProductIds,
        'featured_product_ids': featuredProductIds,
        'product_display_order': productDisplayOrder,
        'nav_categories': navCategories.map((e) => e.toJson()).toList(),
        // Geriye dönük web uyumu
        'categories': {
          for (final c in navCategories)
            c.id: {
              'enabled': c.enabled,
              'label_tr': c.label,
            },
        },
      };

  QrMenuSettings copyWith({
    bool? enabled,
    String? title,
    String? welcomeNote,
    String? baseUrl,
    String? defaultBranchId,
    List<String>? hiddenProductIds,
    List<String>? featuredProductIds,
    List<String>? productDisplayOrder,
    List<QrNavCategory>? navCategories,
  }) {
    return QrMenuSettings(
      enabled: enabled ?? this.enabled,
      title: title ?? this.title,
      welcomeNote: welcomeNote ?? this.welcomeNote,
      baseUrl: baseUrl ?? this.baseUrl,
      defaultBranchId: defaultBranchId ?? this.defaultBranchId,
      hiddenProductIds: hiddenProductIds ?? this.hiddenProductIds,
      featuredProductIds: featuredProductIds ?? this.featuredProductIds,
      productDisplayOrder: productDisplayOrder ?? this.productDisplayOrder,
      navCategories: navCategories ?? this.navCategories,
    );
  }

  @override
  List<Object?> get props => [
        enabled,
        title,
        welcomeNote,
        baseUrl,
        defaultBranchId,
        hiddenProductIds,
        featuredProductIds,
        productDisplayOrder,
        navCategories,
      ];
}
