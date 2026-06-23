import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/orders/order_item_edits.dart';
import '../../../../firebase_options.dart';
import '../../../domain/entities/order.dart';
import '../../../domain/entities/product_extra.dart';
import '../../../domain/entities/paytr_settings.dart';
import '../../../domain/entities/print_routing_settings.dart';
import '../../../domain/entities/delivery_settings.dart';
import '../../../domain/entities/promotion_campaign.dart';
import '../../../domain/entities/waiter_mode_settings.dart';
import '../../mappers/entity_mappers.dart';
import '../../models/api_models.dart';
import 'firestore_datasource.dart';

/// Windows ops: native cloud_firestore olmadan Firestore REST ile sipariş okur.
class FirestoreRestClient {
  FirestoreRestClient({Dio? dio}) : _dio = dio ?? Dio(_baseOptions);

  static final _options = DefaultFirebaseOptions.windows;
  static const _pollInterval = Duration(seconds: 1);

  static BaseOptions get _baseOptions => BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'Accept': 'application/json'},
      );

  final Dio _dio;

  String get _documentsRoot =>
      'https://firestore.googleapis.com/v1/projects/${_options.projectId}/databases/(default)/documents';

  Future<List<Order>> getOrders() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_documentsRoot/orders',
        queryParameters: {
          'key': _options.apiKey,
          'pageSize': 200,
          'orderBy': 'created_at desc',
        },
      );
      return _parseListResponse(response.data);
    } on DioException catch (e) {
      debugPrint('Firestore REST orderBy failed, fallback list: ${e.message}');
      final response = await _dio.get<Map<String, dynamic>>(
        '$_documentsRoot/orders',
        queryParameters: {
          'key': _options.apiKey,
          'pageSize': 200,
        },
      );
      final orders = _parseListResponse(response.data);
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    }
  }

  Stream<List<Order>> watchOrders() async* {
    while (true) {
      try {
        yield await getOrders();
      } catch (e, st) {
        debugPrint('Firestore REST poll failed: $e\n$st');
        yield const [];
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  List<Order> _parseListResponse(Map<String, dynamic>? data) {
    final docs = data?['documents'] as List<dynamic>? ?? const [];
    final orders = <Order>[];
    for (final raw in docs) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        orders.add(_documentToOrder(raw));
      } catch (e) {
        debugPrint('Firestore REST order parse skip: $e');
      }
    }
    return orders;
  }

  Order _documentToOrder(Map<String, dynamic> doc) {
    final name = doc['name'] as String? ?? '';
    final id = name.split('/').last;
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    final json = FirestoreRestValueCodec.documentToJson(fields);
    json['id'] = id;
    return EntityMappers.toOrder(
      OrderModel.fromJson(FirestoreDataSource.normalizeOrderJson(json)),
    );
  }

  Future<Order> getOrder(String orderId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_documentsRoot/orders/${Uri.encodeComponent(orderId)}',
      queryParameters: {'key': _options.apiKey},
    );
    return _documentToOrder(response.data!);
  }

  Future<Order> patchOrder(String orderId, Map<String, dynamic> flatPatch) async {
    final fieldPaths = flatPatch.keys.toList();
    final query = StringBuffer('key=${Uri.encodeComponent(_options.apiKey)}');
    for (final path in fieldPaths) {
      query.write('&updateMask.fieldPaths=${Uri.encodeComponent(path)}');
    }
    final nested = FirestoreRestValueCodec.flatPatchToNested(flatPatch);
    final body = {
      'fields': FirestoreRestValueCodec.encodeDocumentFields(nested),
    };
    await _dio.patch<Map<String, dynamic>>(
      '$_documentsRoot/orders/${Uri.encodeComponent(orderId)}?$query',
      data: body,
      options: Options(contentType: 'application/json'),
    );
    return getOrder(orderId);
  }

  Future<Order> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String? actorId,
    String? actorName,
  }) async {
    final now = DateTime.now().toIso8601String();
    final patch = <String, dynamic>{
      'status': status.name,
      'status_timestamps.${status.name}': now,
    };
    if (actorId != null) {
      patch['status_actor_ids.${status.name}'] = actorId;
    }
    if (actorName != null) {
      patch['status_actor_names.${status.name}'] = actorName;
    }
    return patchOrder(orderId, patch);
  }

  Future<int> nextOrderNumber() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_documentsRoot/meta/order_counter',
        queryParameters: {'key': _options.apiKey},
      );
      final fields = response.data?['fields'] as Map<String, dynamic>? ?? {};
      final json = FirestoreRestValueCodec.documentToJson(fields);
      final current = (json['value'] as num?)?.toInt() ?? 1000;
      final next = current + 1;
      await patchDocument('meta/order_counter', {'value': next});
      return next;
    } catch (e) {
      debugPrint('Firestore REST order counter failed: $e');
      return 1000 + (DateTime.now().millisecondsSinceEpoch % 900000);
    }
  }

  Future<void> patchDocument(String path, Map<String, dynamic> flatPatch) async {
    final fieldPaths = flatPatch.keys.toList();
    final query = StringBuffer('key=${Uri.encodeComponent(_options.apiKey)}');
    for (final fieldPath in fieldPaths) {
      query.write('&updateMask.fieldPaths=${Uri.encodeComponent(fieldPath)}');
    }
    final nested = FirestoreRestValueCodec.flatPatchToNested(flatPatch);
    final body = {
      'fields': FirestoreRestValueCodec.encodeDocumentFields(nested),
    };
    await _dio.patch<Map<String, dynamic>>(
      '$_documentsRoot/$path?$query',
      data: body,
      options: Options(contentType: 'application/json'),
    );
  }

  Future<Order> createOrder(Order order) async {
    final model = EntityMappers.fromOrder(order);
    final json = FirestoreDataSource.normalizeOrderJson(model.toJson());
    final body = {
      'fields': FirestoreRestValueCodec.encodeDocumentFields(json),
    };
    await _dio.post<Map<String, dynamic>>(
      '$_documentsRoot/orders',
      queryParameters: {
        'key': _options.apiKey,
        'documentId': order.id,
      },
      data: body,
      options: Options(contentType: 'application/json'),
    );
    return getOrder(order.id);
  }

  Future<List<AdminUserModel>> getOpsUsers() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '$_documentsRoot/ops_users',
      queryParameters: {'key': _options.apiKey, 'pageSize': 200},
    );
    final docs = response.data?['documents'] as List<dynamic>? ?? const [];
    final users = <AdminUserModel>[];
    for (final raw in docs) {
      if (raw is! Map<String, dynamic>) continue;
      final name = raw['name'] as String? ?? '';
      final id = name.contains('/') ? name.split('/').last : name;
      final fields = FirestoreRestValueCodec.documentToJson(
        raw['fields'] as Map<String, dynamic>? ?? const {},
      );
      users.add(
        AdminUserModel(
          id: id,
          name: fields['name'] as String? ?? '',
          role: fields['role'] as String? ?? 'waiter',
          phone: fields['phone'] as String? ?? '',
          isActive: fields['is_active'] as bool? ?? true,
          branchId: fields['branch_id'] as String?,
          username: fields['username'] as String?,
          password: fields['password'] as String?,
        ),
      );
    }
    return users;
  }

  Future<AdminUserModel?> findOpsUserByUsername(String username) async {
    final users = await getOpsUsers();
    for (final user in users) {
      if (user.username?.toLowerCase() == username) return user;
    }
    return null;
  }

  Future<AdminUserModel> createOpsUser(AdminUserModel user) async {
    final json = <String, dynamic>{
      'name': user.name,
      'role': user.role,
      'phone': user.phone,
      'is_active': user.isActive,
      'branch_id': user.branchId,
      if (user.username != null) 'username': user.username,
      if (user.password != null) 'password': user.password,
    };
    final body = {
      'fields': FirestoreRestValueCodec.encodeDocumentFields(json),
    };
    await _dio.post<Map<String, dynamic>>(
      '$_documentsRoot/ops_users',
      queryParameters: {'key': _options.apiKey, 'documentId': user.id},
      data: body,
      options: Options(contentType: 'application/json'),
    );
    return user;
  }

  Future<AdminUserModel> updateOpsUser(AdminUserModel user) async {
    final json = <String, dynamic>{
      'name': user.name,
      'role': user.role,
      'phone': user.phone,
      'is_active': user.isActive,
      'branch_id': user.branchId,
      if (user.username != null) 'username': user.username,
      if (user.password != null) 'password': user.password,
    };
    final body = {
      'fields': FirestoreRestValueCodec.encodeDocumentFields(json),
    };
    await _dio.patch<Map<String, dynamic>>(
      '$_documentsRoot/ops_users/${user.id}',
      queryParameters: {'key': _options.apiKey},
      data: body,
      options: Options(contentType: 'application/json'),
    );
    return user;
  }

  Future<void> deleteOpsUser(String userId) async {
    await _dio.delete<Map<String, dynamic>>(
      '$_documentsRoot/ops_users/$userId',
      queryParameters: {'key': _options.apiKey},
    );
  }

  Future<List<ProductExtra>> getCatalogExtras() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_documentsRoot/catalog_extras',
        queryParameters: {
          'key': _options.apiKey,
          'pageSize': 200,
        },
      );
      return _parseCatalogExtrasResponse(response.data);
    } catch (e) {
      debugPrint('Firestore REST catalog_extras read failed: $e');
      return const [];
    }
  }

  List<ProductExtra> _parseCatalogExtrasResponse(Map<String, dynamic>? data) {
    final docs = data?['documents'] as List<dynamic>? ?? const [];
    final extras = <ProductExtra>[];
    for (final raw in docs) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        extras.add(_documentToCatalogExtra(raw));
      } catch (e) {
        debugPrint('Firestore REST catalog extra parse skip: $e');
      }
    }
    return extras;
  }

  ProductExtra _documentToCatalogExtra(Map<String, dynamic> doc) {
    final name = doc['name'] as String? ?? '';
    final id = name.split('/').last;
    final fields = doc['fields'] as Map<String, dynamic>? ?? {};
    final json = FirestoreRestValueCodec.documentToJson(fields);
    json['id'] = id;
    return EntityMappers.toProductExtra(ProductExtraModel.fromJson(json));
  }

  Future<PaytrSettings> getPaytrSettings() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_documentsRoot/meta/paytr_settings',
        queryParameters: {'key': _options.apiKey},
      );
      final fields = response.data?['fields'] as Map<String, dynamic>? ?? {};
      final json = FirestoreRestValueCodec.documentToJson(fields);
      return PaytrSettings.fromJson(json);
    } catch (e) {
      debugPrint('Firestore REST paytr settings read failed: $e');
      return PaytrSettings.defaults;
    }
  }

  Future<PaytrSettings> updatePaytrSettings(PaytrSettings settings) async {
    try {
      await patchDocument('meta/paytr_settings', settings.toJson());
    } catch (e) {
      debugPrint('Firestore REST paytr settings patch failed: $e');
    }
    return settings;
  }

  Stream<PaytrSettings> watchPaytrSettings() async* {
    while (true) {
      try {
        yield await getPaytrSettings();
      } catch (e) {
        debugPrint('Firestore REST paytr settings poll failed: $e');
        yield PaytrSettings.defaults;
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  Future<PrintRoutingSettings> getPrintRoutingSettings() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_documentsRoot/meta/print_routing_settings',
        queryParameters: {'key': _options.apiKey},
      );
      final fields = response.data?['fields'] as Map<String, dynamic>? ?? {};
      final json = FirestoreRestValueCodec.documentToJson(fields);
      return PrintRoutingSettings.fromJson(json);
    } catch (e) {
      debugPrint('Firestore REST print routing read failed: $e');
      return PrintRoutingSettings.defaults;
    }
  }

  Future<PrintRoutingSettings> updatePrintRoutingSettings(
    PrintRoutingSettings settings,
  ) async {
    try {
      await patchDocument('meta/print_routing_settings', settings.toJson());
    } catch (e) {
      debugPrint('Firestore REST print routing patch failed: $e');
    }
    return settings;
  }

  Stream<PrintRoutingSettings> watchPrintRoutingSettings() async* {
    while (true) {
      try {
        yield await getPrintRoutingSettings();
      } catch (e) {
        debugPrint('Firestore REST print routing poll failed: $e');
        yield PrintRoutingSettings.defaults;
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  Future<DeliverySettings> getDeliverySettings() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_documentsRoot/meta/delivery_settings',
        queryParameters: {'key': _options.apiKey},
      );
      final fields = response.data?['fields'] as Map<String, dynamic>? ?? {};
      final json = FirestoreRestValueCodec.documentToJson(fields);
      return DeliverySettings.fromJson(json);
    } catch (e) {
      debugPrint('Firestore REST delivery settings read failed: $e');
      return DeliverySettings.defaults;
    }
  }

  Future<DeliverySettings> updateDeliverySettings(
    DeliverySettings settings,
  ) async {
    final normalized = settings.copyWith(
      freeDeliveryMinOrder: settings.freeDeliveryMinOrder.clamp(0, 100000),
    );
    try {
      await patchDocument('meta/delivery_settings', normalized.toJson());
    } catch (e) {
      debugPrint('Firestore REST delivery settings patch failed: $e');
    }
    return normalized;
  }

  Stream<DeliverySettings> watchDeliverySettings() async* {
    while (true) {
      try {
        yield await getDeliverySettings();
      } catch (e) {
        debugPrint('Firestore REST delivery settings poll failed: $e');
        yield DeliverySettings.defaults;
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  Future<List<PromotionCampaign>> getPromotionCampaigns() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_documentsRoot/promotions',
        queryParameters: {'key': _options.apiKey, 'pageSize': 200},
      );
      return _parsePromotionCampaignsResponse(response.data);
    } catch (e) {
      debugPrint('Firestore REST promotions read failed: $e');
      return const [];
    }
  }

  Stream<List<PromotionCampaign>> watchPromotionCampaigns() async* {
    while (true) {
      try {
        yield await getPromotionCampaigns();
      } catch (e) {
        debugPrint('Firestore REST promotions poll failed: $e');
        yield const [];
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  Future<PromotionCampaign?> getPromotionByCode(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final campaigns = await getPromotionCampaigns();
    for (final campaign in campaigns) {
      if (campaign.normalizedCode == normalized && campaign.isActive) {
        return campaign;
      }
    }
    return null;
  }

  Future<PromotionCampaign> createPromotionCampaign(
    PromotionCampaign campaign,
  ) async {
    final body = {
      'fields': FirestoreRestValueCodec.encodeDocumentFields(campaign.toJson()),
    };
    await _dio.post<Map<String, dynamic>>(
      '$_documentsRoot/promotions',
      queryParameters: {
        'key': _options.apiKey,
        'documentId': campaign.id,
      },
      data: body,
      options: Options(contentType: 'application/json'),
    );
    return campaign;
  }

  Future<PromotionCampaign> updatePromotionCampaign(
    PromotionCampaign campaign,
  ) async {
    try {
      await patchDocument('promotions/${campaign.id}', campaign.toJson());
    } catch (e) {
      debugPrint('Firestore REST promotion patch failed: $e');
    }
    return campaign;
  }

  Future<void> deletePromotionCampaign(String id) async {
    await _dio.delete<Map<String, dynamic>>(
      '$_documentsRoot/promotions/$id',
      queryParameters: {'key': _options.apiKey},
    );
  }

  List<PromotionCampaign> _parsePromotionCampaignsResponse(
    Map<String, dynamic>? data,
  ) {
    final docs = data?['documents'] as List<dynamic>? ?? const [];
    final items = <PromotionCampaign>[];
    for (final raw in docs) {
      if (raw is! Map<String, dynamic>) continue;
      try {
        final name = raw['name'] as String? ?? '';
        final id = name.split('/').last;
        final fields = raw['fields'] as Map<String, dynamic>? ?? {};
        final json = FirestoreRestValueCodec.documentToJson(fields);
        json['id'] = json['id'] ?? id;
        items.add(PromotionCampaign.fromJson(json));
      } catch (e) {
        debugPrint('Firestore REST promotion parse skip: $e');
      }
    }
    items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  Future<WaiterModeSettings> getWaiterModeSettings() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '$_documentsRoot/meta/waiter_settings',
        queryParameters: {'key': _options.apiKey},
      );
      final fields = response.data?['fields'] as Map<String, dynamic>? ?? {};
      final json = FirestoreRestValueCodec.documentToJson(fields);
      return WaiterModeSettings.fromJson(json);
    } catch (e) {
      debugPrint('Firestore REST waiter settings read failed: $e');
      return WaiterModeSettings.defaults;
    }
  }

  Future<WaiterModeSettings> updateWaiterModeSettings(
    WaiterModeSettings settings,
  ) async {
    final normalized = settings.copyWith(
      tableCount: settings.tableCount.clamp(1, 99),
    );
    try {
      await patchDocument('meta/waiter_settings', normalized.toJson());
    } catch (e) {
      debugPrint('Firestore REST waiter settings patch failed, try set: $e');
      try {
        final body = {
          'fields': FirestoreRestValueCodec.encodeDocumentFields(
            normalized.toJson(),
          ),
        };
        await _dio.patch<Map<String, dynamic>>(
          '$_documentsRoot/meta/waiter_settings',
          queryParameters: {'key': _options.apiKey},
          data: body,
          options: Options(contentType: 'application/json'),
        );
      } catch (e2) {
        debugPrint('Firestore REST waiter settings write failed: $e2');
      }
    }
    return normalized;
  }

  Future<List<Order>> closeDineInTableBill({
    required String branchId,
    required int tableNumber,
    required PaymentMethod paymentMethod,
    String? paymentTransactionId,
    String? actorId,
    String? actorName,
  }) async {
    final orders = await getOrders();
    final now = DateTime.now().toIso8601String();
    final closed = <Order>[];

    for (final order in orders) {
      if (order.branchId != branchId ||
          order.tableNumber != tableNumber ||
          !order.isDineIn ||
          !order.isActive) {
        continue;
      }
      final patch = <String, dynamic>{
        'status': OrderStatus.delivered.name,
        'status_timestamps.delivered': now,
        'payment_method': paymentMethod.name,
        if (paymentTransactionId != null)
          'payment_transaction_id': paymentTransactionId,
        if (actorId != null) 'status_actor_ids.delivered': actorId,
        if (actorName != null) 'status_actor_names.delivered': actorName,
      };
      closed.add(await patchOrder(order.id, patch));
    }
    return closed;
  }

  Future<List<Order>> voidDineInTableBill({
    required String branchId,
    required int tableNumber,
    String? actorId,
    String? actorName,
  }) async {
    final orders = await getOrders();
    final now = DateTime.now().toIso8601String();
    final cancelled = <Order>[];

    for (final order in orders) {
      if (order.branchId != branchId ||
          order.tableNumber != tableNumber ||
          !order.isDineIn ||
          !order.isActive) {
        continue;
      }
      final patch = <String, dynamic>{
        'status': OrderStatus.cancelled.name,
        'status_timestamps.cancelled': now,
        if (actorId != null) 'status_actor_ids.cancelled': actorId,
        if (actorName != null) 'status_actor_names.cancelled': actorName,
      };
      cancelled.add(await patchOrder(order.id, patch));
    }
    return cancelled;
  }

  Future<Order> removeDineInOrderItem(
    String orderId,
    String cartItemId, {
    int quantity = 1,
    String? actorId,
    String? actorName,
  }) async {
    final order = await getOrder(orderId);
    final updated = applyDineInOrderItemRemoval(
      order: order,
      cartItemId: cartItemId,
      quantity: quantity,
      actorId: actorId,
      actorName: actorName,
    );
    final model = EntityMappers.fromOrder(updated);
    final now = DateTime.now().toIso8601String();
    final patch = <String, dynamic>{
      'items': model.items.map((item) => item.toJson()).toList(),
      'total_amount': updated.totalAmount,
    };
    if (updated.status == OrderStatus.cancelled) {
      patch['status'] = OrderStatus.cancelled.name;
      patch['status_timestamps.cancelled'] = now;
      final cancelActorId = updated.statusActorIds[OrderStatus.cancelled];
      final cancelActorName = updated.statusActorNames[OrderStatus.cancelled];
      if (cancelActorId != null) {
        patch['status_actor_ids.cancelled'] = cancelActorId;
      }
      if (cancelActorName != null) {
        patch['status_actor_names.cancelled'] = cancelActorName;
      }
    }
    return patchOrder(orderId, patch);
  }

  Stream<WaiterModeSettings> watchWaiterModeSettings() async* {
    while (true) {
      try {
        yield await getWaiterModeSettings();
      } catch (e) {
        debugPrint('Firestore REST waiter settings poll failed: $e');
        yield WaiterModeSettings.defaults;
      }
      await Future<void>.delayed(_pollInterval);
    }
  }
}

/// Firestore REST `fields` haritasini uygulama JSON'una cevirir.
abstract final class FirestoreRestValueCodec {
  static Map<String, dynamic> documentToJson(Map<String, dynamic> fields) {
    final out = <String, dynamic>{};
    fields.forEach((key, value) {
      out[key] = decodeValue(value);
    });
    return out;
  }

  static dynamic decodeValue(dynamic value) {
    if (value is! Map<String, dynamic>) return value;
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('integerValue')) {
      return int.tryParse(value['integerValue'].toString()) ??
          value['integerValue'];
    }
    if (value.containsKey('doubleValue')) {
      return (value['doubleValue'] as num).toDouble();
    }
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('nullValue')) return null;
    if (value.containsKey('timestampValue')) {
      return value['timestampValue'] as String;
    }
    if (value.containsKey('mapValue')) {
      final inner = value['mapValue'] as Map<String, dynamic>?;
      final innerFields = inner?['fields'] as Map<String, dynamic>? ?? {};
      return documentToJson(innerFields);
    }
    if (value.containsKey('arrayValue')) {
      final inner = value['arrayValue'] as Map<String, dynamic>?;
      final values = inner?['values'] as List<dynamic>? ?? const [];
      return values.map(decodeValue).toList();
    }
    return value;
  }

  static Map<String, dynamic> flatPatchToNested(Map<String, dynamic> flat) {
    final nested = <String, dynamic>{};
    for (final entry in flat.entries) {
      _setNestedValue(nested, entry.key, entry.value);
    }
    return nested;
  }

  static void _setNestedValue(
    Map<String, dynamic> root,
    String path,
    dynamic value,
  ) {
    final parts = path.split('.');
    var current = root;
    for (var i = 0; i < parts.length - 1; i++) {
      final next = current[parts[i]];
      if (next is Map<String, dynamic>) {
        current = next;
      } else {
        final created = <String, dynamic>{};
        current[parts[i]] = created;
        current = created;
      }
    }
    current[parts.last] = value;
  }

  static Map<String, dynamic> encodeDocumentFields(Map<String, dynamic> json) {
    final fields = <String, dynamic>{};
    json.forEach((key, value) {
      fields[key] = encodeValue(value);
    });
    return fields;
  }

  static Map<String, dynamic> encodeValue(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is String) return {'stringValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is Map) {
      return {
        'mapValue': {
          'fields': encodeDocumentFields(
            Map<String, dynamic>.from(value as Map),
          ),
        },
      };
    }
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map(encodeValue).toList(),
        },
      };
    }
    return {'stringValue': value.toString()};
  }
}
