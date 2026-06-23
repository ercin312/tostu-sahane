import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../domain/entities/delivery_address.dart';
import '../../../domain/entities/order.dart';
import '../../../domain/entities/saved_card.dart';
import '../../../domain/entities/courier_cash_remittance.dart';
import '../../../domain/entities/courier_wallet.dart';
import '../../models/api_models.dart';
import '../../mappers/entity_mappers.dart';

abstract final class LocalStorageKeys {
  static const addresses = 'customer_addresses';
  static const favorites = 'customer_favorite_products';
  static const orders = 'local_orders';
  static const savedCards = 'customer_saved_cards';
  static const courierPayouts = 'courier_payouts';
  static const courierCashRemittances = 'courier_cash_remittances_v1';
}

class AddressLocalDataSource {
  Future<List<DeliveryAddress>> loadAddresses(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${LocalStorageKeys.addresses}_$userId');
    if (raw == null) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list
        .map((e) => DeliveryAddress.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAddresses(
    String userId,
    List<DeliveryAddress> addresses,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(addresses.map((a) => a.toJson()).toList());
    await prefs.setString('${LocalStorageKeys.addresses}_$userId', encoded);
  }
}

class FavoritesLocalDataSource {
  Future<List<String>> loadFavorites(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('${LocalStorageKeys.favorites}_$userId') ?? [];
  }

  Future<void> saveFavorites(String userId, List<String> productIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      '${LocalStorageKeys.favorites}_$userId',
      productIds,
    );
  }
}

class OrderLocalDataSource {
  Future<List<Order>> loadOrders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(LocalStorageKeys.orders);
    if (raw == null) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list
        .map(
          (e) => EntityMappers.toOrder(
            OrderModel.fromJson(e as Map<String, dynamic>),
          ),
        )
        .toList();
  }

  Future<void> saveOrders(List<Order> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(
      orders.map((o) => EntityMappers.fromOrder(o).toJson()).toList(),
    );
    await prefs.setString(LocalStorageKeys.orders, encoded);
  }

  Future<void> clearOrders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(LocalStorageKeys.orders);
  }
}

class SavedCardsLocalDataSource {
  Future<List<SavedCard>> loadCards(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${LocalStorageKeys.savedCards}_$userId');
    if (raw == null) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list
        .map((e) => SavedCard.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveCards(String userId, List<SavedCard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(cards.map((c) => c.toJson()).toList());
    await prefs.setString('${LocalStorageKeys.savedCards}_$userId', encoded);
  }
}

class CourierPayoutLocalDataSource {
  Future<List<CourierWalletEntry>> loadPayouts(String courierId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('${LocalStorageKeys.courierPayouts}_$courierId');
    if (raw == null) return [];
    final list = json.decode(raw) as List<dynamic>;
    return list
        .map((e) => _entryFromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> savePayouts(
    String courierId,
    List<CourierWalletEntry> entries,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(entries.map(_entryToJson).toList());
    await prefs.setString(
      '${LocalStorageKeys.courierPayouts}_$courierId',
      encoded,
    );
  }

  Map<String, dynamic> _entryToJson(CourierWalletEntry entry) => {
        'id': entry.id,
        'type': entry.type.name,
        'amount': entry.amount,
        'created_at': entry.createdAt.toIso8601String(),
        'order_number': entry.orderNumber,
        'payment_kind': entry.paymentKind?.name,
        'note': entry.note,
      };

  CourierWalletEntry _entryFromJson(Map<String, dynamic> json) {
    return CourierWalletEntry(
      id: json['id'] as String,
      type: CourierWalletEntryType.values.byName(json['type'] as String),
      amount: (json['amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      orderNumber: json['order_number'] as int?,
      paymentKind: json['payment_kind'] != null
          ? CourierWalletPaymentKind.values.byName(json['payment_kind'] as String)
          : null,
      note: json['note'] as String?,
    );
  }
}

class CourierCashRemittanceLocalDataSource {
  Future<List<CourierCashRemittance>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(LocalStorageKeys.courierCashRemittances);
    if (raw == null) return _migrateLegacyPayouts(prefs);
    final list = json.decode(raw) as List<dynamic>;
    return list
        .map((e) => CourierCashRemittance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveAll(List<CourierCashRemittance> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = json.encode(items.map((e) => e.toJson()).toList());
    await prefs.setString(LocalStorageKeys.courierCashRemittances, encoded);
  }

  Future<int> purge({String? courierId, String? branchId}) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    final before = all.length;
    if (courierId == null && branchId == null) {
      await prefs.remove(LocalStorageKeys.courierCashRemittances);
      for (final key in prefs.getKeys()) {
        if (key.startsWith('${LocalStorageKeys.courierPayouts}_')) {
          await prefs.remove(key);
        }
      }
      return before;
    }
    final remaining = all.where((item) {
      if (courierId != null && item.courierId == courierId) return false;
      if (branchId != null && item.branchId == branchId) return false;
      return true;
    }).toList();
    await saveAll(remaining);
    return before - remaining.length;
  }

  Future<List<CourierCashRemittance>> _migrateLegacyPayouts(
    SharedPreferences prefs,
  ) async {
    final migrated = <CourierCashRemittance>[];
    final keys = prefs.getKeys().where(
      (k) => k.startsWith('${LocalStorageKeys.courierPayouts}_'),
    );
    for (final key in keys) {
      final courierId = key.replaceFirst('${LocalStorageKeys.courierPayouts}_', '');
      final raw = prefs.getString(key);
      if (raw == null) continue;
      final list = json.decode(raw) as List<dynamic>;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        if (map['type'] != 'payout') continue;
        migrated.add(
          CourierCashRemittance(
            id: map['id'] as String,
            courierId: courierId,
            courierName: '',
            branchId: 'branch_1',
            amount: (map['amount'] as num).toDouble(),
            status: map['note'] == 'courier_payout_pending'
                ? CourierCashRemittanceStatus.pending
                : CourierCashRemittanceStatus.approved,
            requestedAt: DateTime.parse(map['created_at'] as String),
          ),
        );
      }
    }
    if (migrated.isNotEmpty) {
      await saveAll(migrated);
    }
    return migrated;
  }
}
