import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../../../../core/config/app_config.dart';
import '../../../../core/orders/order_item_edits.dart';

import '../../../domain/entities/auth.dart';
import '../../../domain/entities/branch.dart';
import '../../../domain/entities/coupon.dart';
import '../../../domain/entities/order.dart';
import '../../../domain/entities/product_extra.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/product_review.dart';
import '../../../domain/entities/courier_cash_remittance.dart';
import '../../../domain/entities/waiter_mode_settings.dart';
import '../../../domain/entities/paytr_settings.dart';
import '../../../domain/entities/print_routing_settings.dart';
import '../../../domain/entities/delivery_settings.dart';
import '../../../domain/entities/promotion_campaign.dart';
import '../../mappers/entity_mappers.dart';
import '../../mock/mock_data.dart';
import '../../models/api_models.dart';

import 'firestore_rest_client.dart';

/// Firestore production veri katmanı — cihazlar arası senkron.
class FirestoreDataSource {
  FirestoreDataSource({FirebaseFirestore? firestore, FirestoreRestClient? rest})
      : _db = AppConfig.useFirestore
            ? (firestore ?? FirebaseFirestore.instance)
            : null,
        _rest = AppConfig.useWindowsOpsFirestoreRest
            ? (rest ?? FirestoreRestClient())
            : null;

  final FirebaseFirestore? _db;
  final FirestoreRestClient? _rest;

  FirebaseFirestore get _activeDb {
    final db = _db;
    if (db == null) {
      throw StateError('Firestore bu platformda devre disi.');
    }
    return db;
  }

  Future<void>? _seeded;

  static const _branches = 'branches';
  static const _products = 'products';
  static const _orders = 'orders';
  static const _coupons = 'coupons';
  static const _users = 'users';
  static const _meta = 'meta';
  static const _orderCounter = 'order_counter';
  static const _waiterSettings = 'waiter_settings';
  static const _paytrSettings = 'paytr_settings';
  static const _printRoutingSettings = 'print_routing_settings';
  static const _deliverySettings = 'delivery_settings';
  static const _promotions = 'promotions';
  static const _productReviews = 'product_reviews';
  static const _catalogExtras = 'catalog_extras';
  static const _opsUsers = 'ops_users';
  static const _courierCashRemittances = 'courier_cash_remittances';

  CollectionReference<Map<String, dynamic>> get _ordersCol =>
      _activeDb.collection(_orders);

  Future<void> ensureSeeded() async {
    try {
      await (_seeded ??= _ensureSeededOnce()).timeout(AppConfig.apiTimeout);
    } catch (_) {
      _seeded = null;
    }
  }

  Future<void> _ensureSeededOnce() async {
    final productsSnap = await _activeDb.collection(_products).limit(1).get();
    if (productsSnap.docs.isNotEmpty) return;

    final batch = _activeDb.batch();
    for (final branch in MockData.branches) {
      batch.set(
        _activeDb.collection(_branches).doc(branch.id),
        _branchToMap(branch),
      );
    }
    for (final product in MockData.products) {
      batch.set(
        _activeDb.collection(_products).doc(product.id),
        EntityMappers.fromProduct(product).toJson(),
      );
    }
    for (final extra in MockData.catalogExtras) {
      batch.set(
        _activeDb.collection(_catalogExtras).doc(extra.id),
        EntityMappers.fromProductExtra(extra).toJson(),
      );
    }
    for (final coupon in MockData.coupons) {
      batch.set(
        _activeDb.collection(_coupons).doc(coupon.code.toUpperCase()),
        coupon.toJson(),
      );
    }
    batch.set(_activeDb.collection(_meta).doc('seed'), {
      'seeded_at': FieldValue.serverTimestamp(),
    });
    batch.set(_activeDb.collection(_meta).doc(_orderCounter), {'value': 1000});
    batch.set(
      _activeDb.collection(_meta).doc(_waiterSettings),
      WaiterModeSettings.defaults.toJson(),
    );
    batch.set(
      _activeDb.collection(_meta).doc(_paytrSettings),
      PaytrSettings.defaults.toJson(),
    );
    batch.set(
      _activeDb.collection(_meta).doc(_printRoutingSettings),
      PrintRoutingSettings.defaults.toJson(),
    );
    batch.set(
      _activeDb.collection(_meta).doc(_deliverySettings),
      DeliverySettings.defaults.toJson(),
    );
    for (final promo in MockData.promotions) {
      batch.set(
        _activeDb.collection(_promotions).doc(promo.id),
        promo.toJson(),
      );
    }
    for (final opsUser in MockData.demoOpsUsers) {
      batch.set(
        _activeDb.collection(_opsUsers).doc(opsUser.id),
        _opsUserToMap(opsUser),
      );
    }
    await batch.commit();
  }

  Future<void> _ensureDemoOpsUsersSeeded() async {
    for (final user in MockData.demoOpsUsers) {
      final username = user.username?.trim().toLowerCase();
      if (username == null || username.isEmpty) continue;

      if (_rest != null) {
        final existing = await _rest!.findOpsUserByUsername(username);
        if (existing != null) continue;
        try {
          await _rest!.createOpsUser(user);
        } catch (_) {}
        continue;
      }

      final doc = await _activeDb.collection(_opsUsers).doc(user.id).get();
      if (doc.exists) continue;
      try {
        await _activeDb.collection(_opsUsers).doc(user.id).set(_opsUserToMap(user));
      } catch (_) {}
    }
  }

  // ── Waiter mode settings ───────────────────────────────────────────────────

  Future<WaiterModeSettings> getWaiterModeSettings() async {
    if (_rest != null) return _rest!.getWaiterModeSettings();
    await ensureSeeded();
    final doc = await _activeDb.collection(_meta).doc(_waiterSettings).get(
          const GetOptions(source: Source.server),
        );
    if (!doc.exists || doc.data() == null) {
      return WaiterModeSettings.defaults;
    }
    return WaiterModeSettings.fromJson(doc.data()!);
  }

  Stream<WaiterModeSettings> watchWaiterModeSettings() {
    if (_rest != null) return _rest!.watchWaiterModeSettings();
    return _activeDb.collection(_meta).doc(_waiterSettings).snapshots().map(
      (doc) {
        if (!doc.exists || doc.data() == null) {
          return WaiterModeSettings.defaults;
        }
        return WaiterModeSettings.fromJson(doc.data()!);
      },
    );
  }

  Future<WaiterModeSettings> updateWaiterModeSettings(
    WaiterModeSettings settings,
  ) async {
    final normalized = settings.copyWith(
      tableCount: settings.tableCount.clamp(1, 99),
    );
    if (_rest != null) {
      return _rest!.updateWaiterModeSettings(normalized);
    }
    await _activeDb
        .collection(_meta)
        .doc(_waiterSettings)
        .set(normalized.toJson(), SetOptions(merge: true));
    return normalized;
  }

  // ── Print routing ──────────────────────────────────────────────────────────

  Future<PrintRoutingSettings> getPrintRoutingSettings() async {
    if (_rest != null) return _rest!.getPrintRoutingSettings();
    await ensureSeeded();
    final doc = await _activeDb.collection(_meta).doc(_printRoutingSettings).get(
          const GetOptions(source: Source.server),
        );
    if (!doc.exists || doc.data() == null) {
      return PrintRoutingSettings.defaults;
    }
    return PrintRoutingSettings.fromJson(doc.data()!);
  }

  Stream<PrintRoutingSettings> watchPrintRoutingSettings() {
    if (_rest != null) return _rest!.watchPrintRoutingSettings();
    return _activeDb.collection(_meta).doc(_printRoutingSettings).snapshots().map(
      (doc) {
        if (!doc.exists || doc.data() == null) {
          return PrintRoutingSettings.defaults;
        }
        return PrintRoutingSettings.fromJson(doc.data()!);
      },
    );
  }

  Future<PrintRoutingSettings> updatePrintRoutingSettings(
    PrintRoutingSettings settings,
  ) async {
    if (_rest != null) {
      return _rest!.updatePrintRoutingSettings(settings);
    }
    await _activeDb
        .collection(_meta)
        .doc(_printRoutingSettings)
        .set(settings.toJson(), SetOptions(merge: true));
    return settings;
  }

  // ── PayTR settings ─────────────────────────────────────────────────────────

  Future<PaytrSettings> getPaytrSettings() async {
    if (_rest != null) return _rest!.getPaytrSettings();
    await ensureSeeded();
    final doc = await _activeDb.collection(_meta).doc(_paytrSettings).get(
          const GetOptions(source: Source.server),
        );
    if (!doc.exists || doc.data() == null) {
      return PaytrSettings.defaults;
    }
    return PaytrSettings.fromJson(doc.data()!);
  }

  Stream<PaytrSettings> watchPaytrSettings() {
    if (_rest != null) return _rest!.watchPaytrSettings();
    return _activeDb.collection(_meta).doc(_paytrSettings).snapshots().map(
      (doc) {
        if (!doc.exists || doc.data() == null) {
          return PaytrSettings.defaults;
        }
        return PaytrSettings.fromJson(doc.data()!);
      },
    );
  }

  Future<PaytrSettings> updatePaytrSettings(PaytrSettings settings) async {
    final normalized = settings.copyWith(
      vatRatePercent: settings.vatRatePercent.clamp(0, 100),
    );
    if (_rest != null) {
      return _rest!.updatePaytrSettings(normalized);
    }
    await _activeDb
        .collection(_meta)
        .doc(_paytrSettings)
        .set(normalized.toJson(), SetOptions(merge: true));
    return normalized;
  }

  // ── Delivery settings ──────────────────────────────────────────────────────

  Future<DeliverySettings> getDeliverySettings() async {
    if (_rest != null) return _rest!.getDeliverySettings();
    await ensureSeeded();
    final doc = await _activeDb.collection(_meta).doc(_deliverySettings).get(
          const GetOptions(source: Source.server),
        );
    if (!doc.exists || doc.data() == null) {
      return DeliverySettings.defaults;
    }
    return DeliverySettings.fromJson(doc.data()!);
  }

  Stream<DeliverySettings> watchDeliverySettings() {
    if (_rest != null) return _rest!.watchDeliverySettings();
    return _activeDb.collection(_meta).doc(_deliverySettings).snapshots().map(
      (doc) {
        if (!doc.exists || doc.data() == null) {
          return DeliverySettings.defaults;
        }
        return DeliverySettings.fromJson(doc.data()!);
      },
    );
  }

  Future<DeliverySettings> updateDeliverySettings(
    DeliverySettings settings,
  ) async {
    final normalized = settings.copyWith(
      freeDeliveryMinOrder: settings.freeDeliveryMinOrder.clamp(0, 100000),
    );
    if (_rest != null) {
      return _rest!.updateDeliverySettings(normalized);
    }
    await _activeDb
        .collection(_meta)
        .doc(_deliverySettings)
        .set(normalized.toJson(), SetOptions(merge: true));
    return normalized;
  }

  // ── Promotion campaigns ────────────────────────────────────────────────────

  Future<List<PromotionCampaign>> getPromotionCampaigns() async {
    if (_rest != null) return _rest!.getPromotionCampaigns();
    await ensureSeeded();
    final snap = await _activeDb.collection(_promotions).get();
    final items = snap.docs
        .map((doc) => PromotionCampaign.fromJson(doc.data()))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return items;
  }

  Stream<List<PromotionCampaign>> watchPromotionCampaigns() {
    if (_rest != null) return _rest!.watchPromotionCampaigns();
    return _activeDb.collection(_promotions).snapshots().map((snap) {
      final items = snap.docs
          .map((doc) => PromotionCampaign.fromJson(doc.data()))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return items;
    });
  }

  Future<PromotionCampaign?> getPromotionByCode(String code) async {
    if (_rest != null) return _rest!.getPromotionByCode(code);
    await ensureSeeded();
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    final doc = await _activeDb.collection(_promotions).doc(normalized).get();
    if (!doc.exists) {
      final snap = await _activeDb
          .collection(_promotions)
          .where('code', isEqualTo: normalized)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return PromotionCampaign.fromJson(snap.docs.first.data());
    }
    return PromotionCampaign.fromJson(doc.data()!);
  }

  Future<PromotionCampaign> createPromotionCampaign(
    PromotionCampaign campaign,
  ) async {
    if (_rest != null) return _rest!.createPromotionCampaign(campaign);
    await _activeDb
        .collection(_promotions)
        .doc(campaign.id)
        .set(campaign.toJson());
    return campaign;
  }

  Future<PromotionCampaign> updatePromotionCampaign(
    PromotionCampaign campaign,
  ) async {
    if (_rest != null) return _rest!.updatePromotionCampaign(campaign);
    await _activeDb
        .collection(_promotions)
        .doc(campaign.id)
        .set(campaign.toJson(), SetOptions(merge: true));
    return campaign;
  }

  Future<void> deletePromotionCampaign(String id) async {
    if (_rest != null) {
      await _rest!.deletePromotionCampaign(id);
      return;
    }
    await _activeDb.collection(_promotions).doc(id).delete();
  }

  Map<String, dynamic> _branchToMap(Branch branch) => {
        'id': branch.id,
        'name': branch.name,
        'address': branch.address,
        'latitude': branch.latitude,
        'longitude': branch.longitude,
        'distance_km': branch.distanceKm,
        'delivery_zone_mode': branch.deliveryZoneMode.name,
        'delivery_radius_km': branch.deliveryRadiusKm,
        'delivery_polygon': branch.deliveryPolygon
            .map((p) => {'latitude': p.latitude, 'longitude': p.longitude})
            .toList(),
        'open_time': branch.openTime,
        'close_time': branch.closeTime,
        'base_delivery_fee': branch.baseDeliveryFee,
        'free_delivery_min_order': branch.freeDeliveryMinOrder,
        'delivery_fee_per_km': branch.deliveryFeePerKm,
        'prep_time_minutes': branch.prepTimeMinutes,
      };

  // ── Branches ──────────────────────────────────────────────────────────────

  Future<List<Branch>> getBranches() async {
    await ensureSeeded();
    final snap = await _activeDb.collection(_branches).get();
    return snap.docs.map((d) => EntityMappers.toBranch(BranchModel.fromJson({
          ...d.data(),
          'id': d.id,
        }))).toList();
  }

  Future<Branch> createBranch(Branch branch) async {
    await _activeDb.collection(_branches).doc(branch.id).set(_branchToMap(branch));
    return branch;
  }

  Future<Branch> updateBranch(Branch branch) async {
    await _activeDb.collection(_branches).doc(branch.id).update(_branchToMap(branch));
    return branch;
  }

  Future<void> deleteBranch(String branchId) async {
    await _activeDb.collection(_branches).doc(branchId).delete();
  }

  // ── Products ──────────────────────────────────────────────────────────────

  Future<List<Product>> getProducts({String? branchId}) async {
    await ensureSeeded();
    final snap = await _activeDb.collection(_products).get();
    return snap.docs
        .map((d) => EntityMappers.toProduct(
              ProductModel.fromJson({...d.data(), 'id': d.id}),
            ))
        .toList();
  }

  Future<Product> updateProductAvailability(String productId, bool available) async {
    await _activeDb.collection(_products).doc(productId).update({
      'is_available': available,
    });
    final doc = await _activeDb.collection(_products).doc(productId).get();
    return EntityMappers.toProduct(
      ProductModel.fromJson({...doc.data()!, 'id': doc.id}),
    );
  }

  Future<Product> createProduct(Product product) async {
    final data = EntityMappers.fromProduct(product).toJson();
    await _activeDb.collection(_products).doc(product.id).set(data);
    return product;
  }

  Future<Product> updateProduct(Product product) async {
    await _activeDb.collection(_products).doc(product.id).update(
          EntityMappers.fromProduct(product).toJson(),
        );
    return product;
  }

  Future<void> deleteProduct(String productId) async {
    await _activeDb.collection(_products).doc(productId).delete();
  }

  // ── Catalog extras ────────────────────────────────────────────────────────

  Future<void> ensureCatalogExtrasSeeded() async {
    final snap = await _activeDb.collection(_catalogExtras).limit(1).get();
    if (snap.docs.isNotEmpty) return;

    final batch = _activeDb.batch();
    for (final extra in MockData.catalogExtras) {
      batch.set(
        _activeDb.collection(_catalogExtras).doc(extra.id),
        EntityMappers.fromProductExtra(extra).toJson(),
      );
    }
    await batch.commit();
  }

  Future<List<ProductExtra>> getCatalogExtras() async {
    if (_rest != null) return _rest!.getCatalogExtras();
    await ensureCatalogExtrasSeeded();
    final snap = await _activeDb.collection(_catalogExtras).get();
    return snap.docs
        .map(
          (doc) => EntityMappers.toProductExtra(
            ProductExtraModel.fromJson({...doc.data(), 'id': doc.id}),
          ),
        )
        .toList();
  }

  Future<ProductExtra> createCatalogExtra(ProductExtra extra) async {
    await _activeDb
        .collection(_catalogExtras)
        .doc(extra.id)
        .set(EntityMappers.fromProductExtra(extra).toJson());
    return extra;
  }

  Future<ProductExtra> updateCatalogExtra(ProductExtra extra) async {
    await _activeDb
        .collection(_catalogExtras)
        .doc(extra.id)
        .update(EntityMappers.fromProductExtra(extra).toJson());
    return extra;
  }

  Future<void> deleteCatalogExtra(String extraId) async {
    await _activeDb.collection(_catalogExtras).doc(extraId).delete();
  }

  // ── Orders ────────────────────────────────────────────────────────────────

  Future<int> _nextOrderNumber() async {
    if (_rest != null) return _rest!.nextOrderNumber();
    try {
      return await _activeDb.runTransaction((tx) async {
        final ref = _activeDb.collection(_meta).doc(_orderCounter);
        final snap = await tx.get(ref);
        final current = (snap.data()?['value'] as num?)?.toInt() ?? 1000;
        final next = current + 1;
        tx.set(ref, {'value': next});
        return next;
      }).timeout(const Duration(seconds: 15));
    } catch (_) {
      return 1000 + (DateTime.now().millisecondsSinceEpoch % 900000);
    }
  }

  Map<String, dynamic> _orderWriteMap(Order order) {
    final model = EntityMappers.fromOrder(order);
    final data = Map<String, dynamic>.from(model.toJson());
    data['created_at'] = Timestamp.fromDate(order.createdAt);
    if (order.scheduledAt != null) {
      data['scheduled_at'] = Timestamp.fromDate(order.scheduledAt!);
    }
    if (order.statusTimestamps.isNotEmpty) {
      data['status_timestamps'] = {
        for (final entry in order.statusTimestamps.entries)
          entry.key.name: Timestamp.fromDate(entry.value),
      };
    }
    data.removeWhere((_, value) => value == null);
    return data;
  }

  Order _docToOrder(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = _normalizeOrderData({...doc.data()!, 'id': doc.id});
    return EntityMappers.toOrder(OrderModel.fromJson(data));
  }

  static String? _asIsoString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    return value.toString();
  }

  static Map<String, dynamic> normalizeOrderJson(Map<String, dynamic> data) {
    return _normalizeOrderData(data);
  }

  static Map<String, dynamic> _normalizeOrderData(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    normalized['created_at'] = _asIsoString(normalized['created_at']);
    if (normalized['scheduled_at'] != null) {
      normalized['scheduled_at'] = _asIsoString(normalized['scheduled_at']);
    }
    final stamps = normalized['status_timestamps'];
    if (stamps is Map) {
      normalized['status_timestamps'] = stamps.map(
        (key, value) => MapEntry(key.toString(), _asIsoString(value) ?? ''),
      );
    }
    return normalized;
  }

  List<Order> _parseOrderDocs(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final orders = <Order>[];
    for (final doc in docs) {
      try {
        orders.add(_docToOrder(doc));
      } catch (_) {}
    }
    return orders;
  }

  Future<List<Order>> getOrders() async {
    if (_rest != null) return _rest!.getOrders();
    await ensureSeeded();
    final snap = await _ordersCol
        .orderBy('created_at', descending: true)
        .limit(200)
        .get();
    return _parseOrderDocs(snap.docs);
  }

  Stream<List<Order>> watchOrders() {
    if (_rest != null) return _rest!.watchOrders();
    return _ordersCol
        .orderBy('created_at', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => _parseOrderDocs(snap.docs));
  }

  Future<Order> createOrder(Order order) async {
    if (_rest != null) return _rest!.createOrder(order);
    final data = _orderWriteMap(order);
    await _ordersCol.doc(order.id).set(data);
    return order;
  }

  Future<void> deleteAllOrders() async {
    const batchSize = 400;
    while (true) {
      final snap = await _ordersCol.limit(batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = _activeDb.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _activeDb.collection(_meta).doc(_orderCounter).set({'value': 1000});
  }

  Future<Order> buildNewOrderAsync({
    required List<CartItem> items,
    required double totalAmount,
    required String customerId,
    required String customerName,
    required String branchId,
    required String address,
    required PaymentMethod paymentMethod,
    String? orderNote,
    bool deliveryNow = true,
    DateTime? scheduledAt,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? customerPhone,
    String? deliveryDirections,
    String? paymentTransactionId,
    String? couponCode,
    double discountAmount = 0,
    double deliveryFeeAmount = 0,
    int? estimatedDeliveryMinutes,
  }) async {
    await ensureSeeded();
    final orderNumber = await _nextOrderNumber();
    final branch = MockData.branches.firstWhere(
      (b) => b.id == branchId,
      orElse: () => MockData.branches.first,
    );
    final dLat = deliveryLatitude ?? branch.latitude + 0.012;
    final dLng = deliveryLongitude ?? branch.longitude + 0.008;
    final id = 'order_$orderNumber';

    return Order(
      id: id,
      orderNumber: orderNumber,
      customerId: customerId,
      customerName: customerName,
      branchId: branchId,
      items: List.of(items),
      totalAmount: totalAmount,
      status: OrderStatus.received,
      createdAt: DateTime.now(),
      address: address,
      paymentMethod: paymentMethod,
      orderNote: orderNote,
      deliveryNow: deliveryNow,
      scheduledAt: scheduledAt,
      deliveryLatitude: dLat,
      deliveryLongitude: dLng,
      customerPhone: customerPhone,
      deliveryDirections: deliveryDirections,
      paymentTransactionId: paymentTransactionId,
      statusTimestamps: {OrderStatus.received: DateTime.now()},
      couponCode: couponCode,
      discountAmount: discountAmount,
      deliveryFeeAmount: deliveryFeeAmount,
      estimatedDeliveryMinutes: estimatedDeliveryMinutes,
    );
  }

  Future<Order> buildDineInOrderAsync({
    required List<CartItem> items,
    required double totalAmount,
    required String branchId,
    required int tableNumber,
    required String waiterId,
    required String waiterName,
    String? waiterCode,
    String? orderNote,
    List<String> preparationTags = const [],
  }) async {
    if (_db != null) await ensureSeeded();
    final orderNumber = await _nextOrderNumber();
    final now = DateTime.now();
    final id = 'order_$orderNumber';

    return Order(
      id: id,
      orderNumber: orderNumber,
      customerId: waiterId,
      customerName: 'Masa $tableNumber',
      branchId: branchId,
      items: List.of(items),
      totalAmount: totalAmount,
      status: OrderStatus.preparing,
      createdAt: now,
      address: 'Salon - Masa $tableNumber',
      paymentMethod: PaymentMethod.cashOnDelivery,
      orderType: OrderType.dineIn,
      tableNumber: tableNumber,
      waiterId: waiterId,
      waiterName: waiterName,
      waiterCode: waiterCode,
      orderNote: orderNote,
      preparationTags: List<String>.from(preparationTags),
      statusTimestamps: {OrderStatus.preparing: now},
      statusActorIds: {OrderStatus.preparing: waiterId},
      statusActorNames: {OrderStatus.preparing: waiterName},
    );
  }

  Future<List<Order>> closeDineInTableBill({
    required String branchId,
    required int tableNumber,
    required PaymentMethod paymentMethod,
    String? paymentTransactionId,
    String? actorId,
    String? actorName,
  }) async {
    if (_rest != null) {
      return _rest!.closeDineInTableBill(
        branchId: branchId,
        tableNumber: tableNumber,
        paymentMethod: paymentMethod,
        paymentTransactionId: paymentTransactionId,
        actorId: actorId,
        actorName: actorName,
      );
    }

    final snap = await _ordersCol.where('branch_id', isEqualTo: branchId).get();
    final now = DateTime.now().toIso8601String();
    final closed = <Order>[];

    for (final doc in snap.docs) {
      final order = _docToOrder(doc);
      if (order.tableNumber != tableNumber ||
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
      closed.add(await _updateOrder(order.id, patch));
    }
    return closed;
  }

  Future<List<Order>> voidDineInTableBill({
    required String branchId,
    required int tableNumber,
    String? actorId,
    String? actorName,
  }) async {
    if (_rest != null) {
      return _rest!.voidDineInTableBill(
        branchId: branchId,
        tableNumber: tableNumber,
        actorId: actorId,
        actorName: actorName,
      );
    }

    final snap = await _ordersCol.where('branch_id', isEqualTo: branchId).get();
    final now = DateTime.now().toIso8601String();
    final cancelled = <Order>[];

    for (final doc in snap.docs) {
      final order = _docToOrder(doc);
      if (order.tableNumber != tableNumber ||
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
      cancelled.add(await _updateOrder(order.id, patch));
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
    if (_rest != null) {
      return _rest!.removeDineInOrderItem(
        orderId,
        cartItemId,
        quantity: quantity,
        actorId: actorId,
        actorName: actorName,
      );
    }

    final order = await _getOrder(orderId);
    final updated = applyDineInOrderItemRemoval(
      order: order,
      cartItemId: cartItemId,
      quantity: quantity,
      actorId: actorId,
      actorName: actorName,
    );
    return _patchOrderItems(updated);
  }

  Future<Order> _patchOrderItems(Order updated) async {
    final model = EntityMappers.fromOrder(updated);
    final now = DateTime.now().toIso8601String();
    final patch = <String, dynamic>{
      'items': model.items.map((item) => item.toJson()).toList(),
      'total_amount': updated.totalAmount,
    };
    if (updated.status == OrderStatus.cancelled) {
      patch['status'] = OrderStatus.cancelled.name;
      patch['status_timestamps.cancelled'] = now;
      final actorId = updated.statusActorIds[OrderStatus.cancelled];
      final actorName = updated.statusActorNames[OrderStatus.cancelled];
      if (actorId != null) {
        patch['status_actor_ids.cancelled'] = actorId;
      }
      if (actorName != null) {
        patch['status_actor_names.cancelled'] = actorName;
      }
    }
    return _updateOrder(updated.id, patch);
  }

  Future<Order> _updateOrder(String orderId, Map<String, dynamic> patch) async {
    if (_rest != null) {
      return _rest!.patchOrder(orderId, patch);
    }
    await _ordersCol.doc(orderId).update(patch);
    final doc = await _ordersCol.doc(orderId).get();
    return _docToOrder(doc);
  }

  Future<Order> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String? actorId,
    String? actorName,
  }) async {
    if (_rest != null) {
      return _rest!.updateOrderStatus(
        orderId,
        status,
        actorId: actorId,
        actorName: actorName,
      );
    }
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
    return _updateOrder(orderId, patch);
  }

  Future<Order> cancelOrder(
    String orderId, {
    String? actorId,
    String? actorName,
  }) =>
      updateOrderStatus(
        orderId,
        OrderStatus.cancelled,
        actorId: actorId,
        actorName: actorName,
      );

  Future<Order> _getOrder(String orderId) async {
    if (_rest != null) return _rest!.getOrder(orderId);
    final doc = await _ordersCol.doc(orderId).get();
    return _docToOrder(doc);
  }

  Future<Order> assignCourier(
    String orderId,
    String courierId,
    String courierName, {
    String? actorId,
    String? actorName,
  }) async {
    final order = await _getOrder(orderId);
    final branch = MockData.branches.firstWhere(
      (b) => b.id == order.branchId,
      orElse: () => MockData.branches.first,
    );
    final now = DateTime.now().toIso8601String();
    final resolvedActorId = actorId ?? courierId;
    final resolvedActorName = actorName ?? courierName;
    final patch = <String, dynamic>{
      'status': OrderStatus.onTheWay.name,
      'courier_id': courierId,
      'courier_name': courierName,
      'courier_latitude': branch.latitude,
      'courier_longitude': branch.longitude,
      'status_timestamps.${OrderStatus.onTheWay.name}': now,
      'status_actor_ids.${OrderStatus.onTheWay.name}': resolvedActorId,
      'status_actor_names.${OrderStatus.onTheWay.name}': resolvedActorName,
    };
    if (!order.statusTimestamps.containsKey(OrderStatus.waitingCourier)) {
      patch['status_timestamps.${OrderStatus.waitingCourier.name}'] = now;
    }
    return _updateOrder(orderId, patch);
  }

  Future<Order> markApproachNotificationSent(String orderId) async {
    return _updateOrder(orderId, {'approach_notification_sent': true});
  }

  Future<Order> updateCourierLocation(
    String orderId,
    double latitude,
    double longitude,
  ) async {
    return _updateOrder(orderId, {
      'courier_latitude': latitude,
      'courier_longitude': longitude,
    });
  }

  Future<Order> rateOrder(String orderId, int rating, {String? comment}) async {
    final doc = await _ordersCol.doc(orderId).get();
    if (!doc.exists) {
      throw StateError('Order not found: $orderId');
    }
    final order = _docToOrder(doc);
    if (order.items.isEmpty) return order;

    final reviewId = 'review_order_$orderId';
    final reviewDoc =
        await _activeDb.collection(_productReviews).doc(reviewId).get();
    final review = ProductReview(
      id: reviewId,
      productId: order.items.first.productId,
      orderId: orderId,
      customerId: order.customerId,
      customerName: order.customerName,
      rating: rating,
      comment: comment ?? '',
      createdAt: DateTime.now(),
    );
    if (reviewDoc.exists) {
      await _activeDb.collection(_productReviews).doc(reviewId).update({
        'rating': rating,
        'comment': comment ?? '',
        'created_at': DateTime.now().toIso8601String(),
        'is_approved': false,
      });
    } else {
      await submitProductReview(review);
    }
    return order;
  }

  // ── Coupons ───────────────────────────────────────────────────────────────

  Future<Coupon?> getCoupon(String code) async {
    await ensureSeeded();
    final doc = await _activeDb
        .collection(_coupons)
        .doc(code.trim().toUpperCase())
        .get();
    if (!doc.exists) return null;
    return Coupon.fromJson(doc.data()!);
  }

  // ── Auth / Push ───────────────────────────────────────────────────────────

  Future<void> sendOtp(String phone, String role) async {}

  Future<void> sendEmailOtp(String email, String role) async {}

  Future<AuthUserModel> verifyOtp(String phone, String otp, String role) async {
    if (otp != MockData.demoOtp) {
      throw const AuthCredentialsException('auth_invalid_otp');
    }
    return _authUser(role: role, phone: phone);
  }

  Future<AuthUserModel> verifyEmailOtp(
    String email,
    String otp,
    String role,
  ) async {
    if (otp != MockData.demoOtp) {
      throw const AuthCredentialsException('auth_invalid_otp');
    }
    return _authUser(role: role, phone: email);
  }

  Future<AuthUserModel> loginWithEmailPassword(
    String email,
    String password,
    String role,
  ) async {
    if (role == 'waiter' || role == 'kitchenStaff') {
      return _loginOpsUsername(email, password, role);
    }
    if (password != MockData.demoPassword) {
      throw const AuthCredentialsException('auth_invalid_credentials');
    }
    return _authUser(role: role, phone: email);
  }

  Future<AuthUserModel> _loginOpsUsername(
    String username,
    String password,
    String expectedRole,
  ) async {
    await _ensureDemoOpsUsersSeeded();

    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) {
      throw const AuthCredentialsException('auth_invalid_credentials');
    }

    if (_rest != null) {
      final user = await _rest!.findOpsUserByUsername(normalized);
      if (user == null ||
          user.role != expectedRole ||
          user.isActive != true ||
          user.password != password) {
        throw const AuthCredentialsException('auth_invalid_credentials');
      }
      return AuthUserModel(
        id: user.id,
        name: user.name,
        role: user.role,
        phone: user.phone,
        branchId: user.branchId,
        username: user.username,
        accessToken: 'firestore_token',
        refreshToken: 'firestore_refresh',
      );
    }

    final snap = await _activeDb
        .collection(_opsUsers)
        .where('username', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      throw const AuthCredentialsException('auth_invalid_credentials');
    }
    final data = snap.docs.first.data();
    if (data['role'] != expectedRole ||
        data['is_active'] != true ||
        data['password'] != password) {
      throw const AuthCredentialsException('auth_invalid_credentials');
    }
    return AuthUserModel(
      id: snap.docs.first.id,
      name: data['name'] as String,
      role: data['role'] as String,
      phone: data['phone'] as String? ?? '',
      branchId: data['branch_id'] as String?,
      username: data['username'] as String?,
      accessToken: 'firestore_token',
      refreshToken: 'firestore_refresh',
    );
  }

  AuthUserModel _authUser({required String role, required String phone}) {
    final branchId =
        role == 'branchManager' ||
            role == 'branchStaff' ||
            role == 'courier' ||
            role == 'waiter' ||
            role == 'kitchenStaff'
        ? 'branch_1'
        : null;
    final id = switch (role) {
      'branchManager' => 'u1',
      'courier' => 'u2',
      'branchStaff' => 'u3',
      _ => '${role}_$phone',
    };
    return AuthUserModel(
      id: id,
      name: role,
      role: role,
      phone: phone,
      branchId: branchId,
      accessToken: 'firestore_token',
      refreshToken: 'firestore_refresh',
    );
  }

  Future<void> registerPushToken(
    String token, {
    required String userId,
    required String role,
    String? branchId,
  }) async {
    await _activeDb.collection(_users).doc(userId).set({
      'fcm_token': token,
      'role': role,
      'branch_id': branchId,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Admin ─────────────────────────────────────────────────────────────────

  Future<List<AdminUserModel>> getAdminUsers() async {
    if (_rest != null) {
      return _rest!.getOpsUsers();
    }
    final snap = await _activeDb.collection(_opsUsers).get();
    if (snap.docs.isEmpty) return _defaultOpsUsers();
    return snap.docs.map(_docToOpsUser).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<AdminUserModel> _defaultOpsUsers() => [
        const AdminUserModel(
          id: 'u1',
          name: 'auth_role_branch',
          role: 'branchManager',
          phone: '5551112233',
          isActive: true,
          branchId: 'branch_1',
        ),
        const AdminUserModel(
          id: 'u2',
          name: 'auth_role_courier',
          role: 'courier',
          phone: '5554445566',
          isActive: true,
          branchId: 'branch_1',
        ),
        const AdminUserModel(
          id: 'u3',
          name: 'auth_role_branch_staff',
          role: 'branchStaff',
          phone: '5557778899',
          isActive: true,
          branchId: 'branch_1',
        ),
      ];

  AdminUserModel _docToOpsUser(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AdminUserModel(
      id: doc.id,
      name: data['name'] as String,
      role: data['role'] as String,
      phone: data['phone'] as String? ?? '',
      isActive: data['is_active'] as bool? ?? true,
      branchId: data['branch_id'] as String?,
      username: data['username'] as String?,
      password: data['password'] as String?,
    );
  }

  Map<String, dynamic> _opsUserToMap(AdminUserModel user) => {
        'name': user.name,
        'role': user.role,
        'phone': user.phone,
        'is_active': user.isActive,
        'branch_id': user.branchId,
        if (user.username != null) 'username': user.username!.trim().toLowerCase(),
        if (user.password != null) 'password': user.password,
      };

  Future<AdminUserModel> createAdminUser(AdminUserModel user) async {
    final id = user.id.isNotEmpty ? user.id : 'user_${DateTime.now().millisecondsSinceEpoch}';
    final prepared = user.copyWith(
      id: id,
      username: user.username?.trim().toLowerCase(),
    );
    if (_rest != null) {
      return _rest!.createOpsUser(prepared);
    }
    await _activeDb.collection(_opsUsers).doc(id).set(_opsUserToMap(prepared));
    return prepared;
  }

  Future<AdminUserModel> updateAdminUser(AdminUserModel user) async {
    final prepared = user.copyWith(
      username: user.username?.trim().toLowerCase(),
    );
    if (_rest != null) {
      return _rest!.updateOpsUser(prepared);
    }
    await _activeDb.collection(_opsUsers).doc(user.id).set(
          _opsUserToMap(prepared),
          SetOptions(merge: true),
        );
    return prepared;
  }

  Future<void> deleteAdminUser(String userId) async {
    if (_rest != null) {
      await _rest!.deleteOpsUser(userId);
      return;
    }
    await _activeDb.collection(_opsUsers).doc(userId).delete();
  }

  Future<AdminReportModel> getAdminReports() async {
    final orders = await getOrders();
    final branches = await getBranches();
    final revenue = orders.fold<double>(0, (s, o) => s + o.totalAmount);
    return AdminReportModel(
      totalRevenue: revenue,
      totalOrders: orders.length,
      activeBranches: branches.length,
    );
  }


  ProductReview _docToReview(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ProductReview(
      id: doc.id,
      productId: data['product_id'] as String,
      orderId: data['order_id'] as String?,
      customerId: data['customer_id'] as String,
      customerName: data['customer_name'] as String,
      rating: (data['rating'] as num).toInt(),
      comment: data['comment'] as String? ?? '',
      createdAt: DateTime.parse(data['created_at'] as String),
      isApproved: data['is_approved'] as bool? ?? false,
    );
  }

  Future<List<ProductReview>> getCustomerProductReviews(String customerId) async {
    final snap = await _activeDb
        .collection(_productReviews)
        .where('customer_id', isEqualTo: customerId)
        .get();
    return snap.docs.map(_docToReview).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<ProductReview>> getApprovedProductReviews(String productId) async {
    final snap = await _activeDb
        .collection(_productReviews)
        .where('product_id', isEqualTo: productId)
        .get();
    return snap.docs.map(_docToReview).where((r) => r.isApproved).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<ProductReview>> getPendingProductReviews() async {
    final snap = await _activeDb
        .collection(_productReviews)
        .where('is_approved', isEqualTo: false)
        .get();
    return snap.docs.map(_docToReview).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Stream<List<ProductReview>> watchPendingProductReviews() {
    return _activeDb
        .collection(_productReviews)
        .where('is_approved', isEqualTo: false)
        .snapshots()
        .map(
          (snap) => snap.docs.map(_docToReview).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        );
  }

  Future<ProductReview> submitProductReview(ProductReview review) async {
    final data = {
      'product_id': review.productId,
      'customer_id': review.customerId,
      'customer_name': review.customerName,
      'rating': review.rating,
      'comment': review.comment,
      'created_at': review.createdAt.toIso8601String(),
      'is_approved': false,
      if (review.orderId != null) 'order_id': review.orderId,
    };
    await _activeDb.collection(_productReviews).doc(review.id).set(data);
    return review;
  }

  Future<ProductReview> approveProductReview(String reviewId) async {
    final doc = await _activeDb.collection(_productReviews).doc(reviewId).get();
    final review = _docToReview(doc);
    await _activeDb.collection(_productReviews).doc(reviewId).update({
      'is_approved': true,
    });
    if (review.orderId != null) {
      await _updateOrder(review.orderId!, {
        'rating': review.rating,
        if (review.comment.isNotEmpty) 'rating_comment': review.comment,
      });
    }
    final updatedDoc =
        await _activeDb.collection(_productReviews).doc(reviewId).get();
    return _docToReview(updatedDoc);
  }

  Future<void> rejectProductReview(String reviewId) async {
    await _activeDb.collection(_productReviews).doc(reviewId).delete();
  }

  // ── Kurye kasa teslimi ────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _remittancesCol =>
      _activeDb.collection(_courierCashRemittances);

  CourierCashRemittance _docToRemittance(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return CourierCashRemittance.fromJson({...doc.data()!, 'id': doc.id});
  }

  Future<CourierCashRemittance> createCashRemittance(
    CourierCashRemittance remittance,
  ) async {
    await _remittancesCol.doc(remittance.id).set(remittance.toJson());
    return remittance;
  }

  Future<List<CourierCashRemittance>> getCashRemittances({
    String? courierId,
    String? branchId,
    CourierCashRemittanceStatus? status,
  }) async {
    Query<Map<String, dynamic>> query = _remittancesCol;
    if (courierId != null) {
      query = query.where('courier_id', isEqualTo: courierId);
    }
    if (branchId != null) {
      query = query.where('branch_id', isEqualTo: branchId);
    }
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    final snap = await query.get();
    final items = snap.docs.map(_docToRemittance).toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
    return items;
  }

  Stream<List<CourierCashRemittance>> watchCashRemittances({
    String? courierId,
    String? branchId,
  }) {
    Query<Map<String, dynamic>> query = _remittancesCol;
    if (courierId != null) {
      query = query.where('courier_id', isEqualTo: courierId);
    }
    if (branchId != null) {
      query = query.where('branch_id', isEqualTo: branchId);
    }
    return query.snapshots().map(
      (snap) {
        final items = snap.docs.map(_docToRemittance).toList()
          ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
        return items;
      },
    );
  }

  Future<CourierCashRemittance> reviewCashRemittance({
    required String remittanceId,
    required CourierCashRemittanceStatus status,
    required String reviewerId,
    required String reviewerName,
    String? rejectionReason,
  }) async {
    final patch = <String, dynamic>{
      'status': status.name,
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by_id': reviewerId,
      'reviewed_by_name': reviewerName,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
    };
    await _remittancesCol.doc(remittanceId).update(patch);
    final doc = await _remittancesCol.doc(remittanceId).get();
    return _docToRemittance(doc);
  }

  // ── Operasyonel test verisi temizliği ─────────────────────────────────────

  Future<int> _deleteQueryInBatches(
    Query<Map<String, dynamic>> query, {
    int batchSize = 400,
  }) async {
    var deleted = 0;
    while (true) {
      final snap = await query.limit(batchSize).get();
      if (snap.docs.isEmpty) break;
      final batch = _activeDb.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snap.docs.length;
    }
    return deleted;
  }

  Future<int> deleteOrders({
    String? courierId,
    String? branchId,
    bool resetCounterWhenAll = false,
  }) async {
    Query<Map<String, dynamic>> query = _ordersCol;
    if (courierId != null) {
      query = query.where('courier_id', isEqualTo: courierId);
    } else if (branchId != null) {
      query = query.where('branch_id', isEqualTo: branchId);
    }
    final deleted = await _deleteQueryInBatches(query);
    if (resetCounterWhenAll && courierId == null && branchId == null) {
      await _activeDb.collection(_meta).doc(_orderCounter).set({'value': 1000});
    }
    return deleted;
  }

  Future<int> deleteAllProductReviews({Set<String>? orderIds}) async {
    final snap = await _activeDb.collection(_productReviews).get();
    final refs = snap.docs.where((doc) {
      if (orderIds == null) return true;
      final orderId = doc.data()['order_id'] as String?;
      return orderId != null && orderIds.contains(orderId);
    }).map((doc) => doc.reference).toList();

    var deleted = 0;
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _activeDb.batch();
      final chunk = refs.skip(i).take(400);
      for (final ref in chunk) {
        batch.delete(ref);
      }
      await batch.commit();
      deleted += chunk.length;
    }
    return deleted;
  }

  Future<int> deleteCashRemittances({
    String? courierId,
    String? branchId,
  }) async {
    Query<Map<String, dynamic>> query = _remittancesCol;
    if (courierId != null) {
      query = query.where('courier_id', isEqualTo: courierId);
    } else if (branchId != null) {
      query = query.where('branch_id', isEqualTo: branchId);
    }
    return _deleteQueryInBatches(query);
  }

  Future<Set<String>> collectOrderIds({
    String? courierId,
    String? branchId,
  }) async {
    Query<Map<String, dynamic>> query = _ordersCol;
    if (courierId != null) {
      query = query.where('courier_id', isEqualTo: courierId);
    } else if (branchId != null) {
      query = query.where('branch_id', isEqualTo: branchId);
    }
    final snap = await query.get();
    return snap.docs.map((doc) => doc.id).toSet();
  }
}
