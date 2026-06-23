import 'dart:async';

import '../../../core/orders/order_item_edits.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/coupon.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_extra.dart';
import '../../domain/entities/product_review.dart';
import '../../domain/entities/auth.dart';
import '../../domain/entities/waiter_mode_settings.dart';
import '../../domain/entities/paytr_settings.dart';
import '../../domain/entities/delivery_settings.dart';
import '../../domain/entities/promotion_campaign.dart';
import '../../domain/entities/print_routing_settings.dart';
import '../mappers/entity_mappers.dart';
import '../mock/mock_data.dart';
import '../models/api_models.dart';
import '../models/payment_models.dart';

/// Simüle edilmiş API — gerçek backend hazır olana kadar mock veri döner.
class MockApiDataSource {
  MockApiDataSource()
      : _orders = [],
        _waiterModeSettings = WaiterModeSettings.defaults,
        _printRoutingSettings = PrintRoutingSettings.defaults,
        _branches = List<Branch>.of(MockData.branches),
        _adminUsers = List<AdminUserModel>.of(MockData.demoOpsUsers, growable: true)
          ..insertAll(0, [
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
          ]);

  final List<Order> _orders;
  List<Branch> _branches;
  WaiterModeSettings _waiterModeSettings;
  PrintRoutingSettings _printRoutingSettings;
  PaytrSettings _paytrSettings = PaytrSettings.defaults;
  DeliverySettings _deliverySettings = DeliverySettings.defaults;
  List<PromotionCampaign> _promotions = List<PromotionCampaign>.of(
    MockData.promotions,
  );
  var _products = List<Product>.of(MockData.products);
  var _catalogExtras = List<ProductExtra>.of(MockData.catalogExtras);
  List<AdminUserModel> _adminUsers;
  var _orderCounter = 1000;

  Future<List<Branch>> getBranches() async {
    await _delay();
    return List.of(_branches);
  }

  Future<Branch> createBranch(Branch branch) async {
    await _delay();
    _branches = [..._branches, branch];
    return branch;
  }

  Future<Branch> updateBranch(Branch branch) async {
    await _delay();
    _branches = [
      for (final b in _branches) if (b.id == branch.id) branch else b,
    ];
    return branch;
  }

  Future<void> deleteBranch(String branchId) async {
    await _delay();
    _branches = _branches.where((b) => b.id != branchId).toList();
  }

  Future<List<Product>> getProducts({String? branchId}) async {
    await _delay();
    return List.of(_products);
  }

  Future<Product> updateProductAvailability(String productId, bool available) async {
    await _delay();
    _products = [
      for (final p in _products)
        if (p.id == productId) p.copyWith(isAvailable: available) else p,
    ];
    return _products.firstWhere((p) => p.id == productId);
  }

  Future<Product> createProduct(Product product) async {
    await _delay();
    _products = [..._products, product];
    return product;
  }

  Future<Product> updateProduct(Product product) async {
    await _delay();
    _products = [
      for (final p in _products) if (p.id == product.id) product else p,
    ];
    return product;
  }

  Future<void> deleteProduct(String productId) async {
    await _delay();
    _products = _products.where((p) => p.id != productId).toList();
  }

  Future<List<ProductExtra>> getCatalogExtras() async {
    await _delay();
    return List.of(_catalogExtras);
  }

  Future<ProductExtra> createCatalogExtra(ProductExtra extra) async {
    await _delay();
    _catalogExtras = [..._catalogExtras, extra];
    return extra;
  }

  Future<ProductExtra> updateCatalogExtra(ProductExtra extra) async {
    await _delay();
    _catalogExtras = [
      for (final item in _catalogExtras) if (item.id == extra.id) extra else item,
    ];
    return extra;
  }

  Future<void> deleteCatalogExtra(String extraId) async {
    await _delay();
    _catalogExtras = _catalogExtras.where((e) => e.id != extraId).toList();
  }

  Future<List<Order>> getOrders() async {
    await _delay();
    _simulateCourierLocations();
    return List.of(_orders);
  }

  void purgeAllOrders() {
    _orders.clear();
    _orderCounter = 1000;
  }

  int purgeOrders({String? courierId, String? branchId}) {
    final before = _orders.length;
    _orders.removeWhere((order) {
      if (courierId != null) return order.courierId == courierId;
      if (branchId != null) return order.branchId == branchId;
      return true;
    });
    if (courierId == null && branchId == null) {
      _orderCounter = 1000;
    }
    return before - _orders.length;
  }

  int purgeProductReviews({Set<String>? orderIds}) {
    final before = _productReviews.length;
    if (orderIds == null || orderIds.isEmpty) {
      _productReviews.clear();
    } else {
      _productReviews.removeWhere(
        (review) =>
            review.orderId != null && orderIds.contains(review.orderId),
      );
    }
    return before - _productReviews.length;
  }

  Set<String> collectOrderIds({String? courierId, String? branchId}) {
    return _orders
        .where((order) {
          if (courierId != null) return order.courierId == courierId;
          if (branchId != null) return order.branchId == branchId;
          return true;
        })
        .map((order) => order.id)
        .toSet();
  }

  void upsertOrder(Order order) {
    final index = _orders.indexWhere((o) => o.id == order.id);
    if (index >= 0) {
      _orders[index] = order;
    } else {
      _orders.insert(0, order);
    }
  }

  Future<void> syncOrders(Iterable<Order> orders) async {
    for (final order in orders) {
      upsertOrder(order);
    }
  }

  Order? findOrder(String orderId) {
    for (final order in _orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  Future<Order> createOrder(Order order) async {
    await _delay();
    _orders.insert(0, order);
    return order;
  }

  Future<Order> updateOrderStatus(
    String orderId,
    OrderStatus status, {
    String? actorId,
    String? actorName,
  }) async {
    await _delay();
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) {
      throw StateError('Order not found: $orderId');
    }
    final updated = _orders[index].withStatus(
      status,
      actorId: actorId,
      actorName: actorName,
    );
    _orders[index] = updated;
    return updated;
  }

  Future<Order> cancelOrder(
    String orderId, {
    String? actorId,
    String? actorName,
  }) async {
    return updateOrderStatus(
      orderId,
      OrderStatus.cancelled,
      actorId: actorId,
      actorName: actorName,
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
    await _delay();
    final closed = <Order>[];
    for (var i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      if (order.branchId != branchId ||
          order.tableNumber != tableNumber ||
          !order.isDineIn ||
          !order.isActive) {
        continue;
      }
      final updated = order
          .copyWith(
            paymentMethod: paymentMethod,
            paymentTransactionId: paymentTransactionId,
          )
          .withStatus(
            OrderStatus.delivered,
            actorId: actorId,
            actorName: actorName,
          );
      _orders[i] = updated;
      closed.add(updated);
    }
    return closed;
  }

  Future<List<Order>> voidDineInTableBill({
    required String branchId,
    required int tableNumber,
    String? actorId,
    String? actorName,
  }) async {
    await _delay();
    final cancelled = <Order>[];
    for (var i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      if (order.branchId != branchId ||
          order.tableNumber != tableNumber ||
          !order.isDineIn ||
          !order.isActive) {
        continue;
      }
      final updated = order.withStatus(
        OrderStatus.cancelled,
        actorId: actorId,
        actorName: actorName,
      );
      _orders[i] = updated;
      cancelled.add(updated);
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
    await _delay();
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) {
      throw StateError('Order not found: $orderId');
    }
    final updated = applyDineInOrderItemRemoval(
      order: _orders[index],
      cartItemId: cartItemId,
      quantity: quantity,
      actorId: actorId,
      actorName: actorName,
    );
    _orders[index] = updated;
    return updated;
  }

  Future<Order> rateOrder(String orderId, int rating, {String? comment}) async {
    await _delay();
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) {
      throw StateError('Order not found: $orderId');
    }
    final order = _orders[index];
    if (order.items.isEmpty) return order;

    final existingReview = _productReviews.indexWhere(
      (r) => r.orderId == orderId && !r.isApproved,
    );
    if (existingReview >= 0) {
      _productReviews[existingReview] = _productReviews[existingReview].copyWith(
        rating: rating,
        comment: comment ?? '',
        createdAt: DateTime.now(),
      );
    } else {
      await submitProductReview(
        ProductReview(
          id: 'review_order_$orderId',
          productId: order.items.first.productId,
          orderId: orderId,
          customerId: order.customerId,
          customerName: order.customerName,
          rating: rating,
          comment: comment ?? '',
          createdAt: DateTime.now(),
        ),
      );
      return order;
    }
    _notifyReviewChange();
    return order;
  }

  Future<Order> assignCourier(
    String orderId,
    String courierId,
    String courierName, {
    String? actorId,
    String? actorName,
  }) async {
    await _delay();
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) {
      throw StateError('Order not found: $orderId');
    }
    final order = _orders[index];
    final branch = _branches.firstWhere(
      (b) => b.id == order.branchId,
      orElse: () => _branches.first,
    );
    var updated = order
        .copyWith(
          courierId: courierId,
          courierName: courierName,
          courierLatitude: branch.latitude,
          courierLongitude: branch.longitude,
        )
        .withStatus(
          OrderStatus.onTheWay,
          actorId: actorId ?? courierId,
          actorName: actorName ?? courierName,
        );
    _orders[index] = updated;
    return updated;
  }

  Future<Order> markApproachNotificationSent(String orderId) async {
    await _delay();
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index < 0) {
      throw StateError('Order not found: $orderId');
    }
    final updated =
        _orders[index].copyWith(approachNotificationSent: true);
    _orders[index] = updated;
    return updated;
  }

  Future<Order> updateCourierLocation(
    String orderId,
    double latitude,
    double longitude,
  ) async {
    await _delay();
    final index = _orders.indexWhere((o) => o.id == orderId);
    final updated = _orders[index].copyWith(
      courierLatitude: latitude,
      courierLongitude: longitude,
    );
    _orders[index] = updated;
    return updated;
  }

  void _simulateCourierLocations() {
    for (var i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      if (order.status != OrderStatus.onTheWay) continue;
      final dLat = order.deliveryLatitude;
      final dLng = order.deliveryLongitude;
      if (dLat == null || dLng == null) continue;

      final branch = _branches.firstWhere(
        (b) => b.id == order.branchId,
        orElse: () => _branches.first,
      );
      final cLat = order.courierLatitude ?? branch.latitude;
      final cLng = order.courierLongitude ?? branch.longitude;
      final progress = 0.06;
      _orders[i] = order.copyWith(
        courierLatitude: cLat + (dLat - cLat) * progress,
        courierLongitude: cLng + (dLng - cLng) * progress,
      );
    }
  }

  Future<void> sendOtp(String phone, String role) async => _delay();

  Future<void> sendEmailOtp(String email, String role) async => _delay();

  AuthUserModel _mockAuthUser({
    required String role,
    required String phone,
  }) {
    final branchId = role == 'branchManager' ||
            role == 'branchStaff' ||
            role == 'courier' ||
            role == 'waiter'
        ? 'branch_1'
        : null;
    final identityKey = phone.contains('@')
        ? phone.trim().toLowerCase()
        : phone.replaceAll(RegExp(r'\D'), '');
    final id = switch (role) {
      'branchManager' => 'u1',
      'courier' => 'u2',
      'branchStaff' => 'u3',
      _ => '${role}_$identityKey',
    };
    return AuthUserModel(
      id: id,
      name: role,
      role: role,
      phone: identityKey,
      branchId: branchId,
      accessToken: 'mock_access_token',
      refreshToken: 'mock_refresh_token',
    );
  }

  Future<AuthUserModel> verifyOtp(String phone, String otp, String role) async {
    await _delay();
    if (otp != MockData.demoOtp) {
      throw const AuthCredentialsException('auth_invalid_otp');
    }
    return _mockAuthUser(role: role, phone: phone);
  }

  Future<AuthUserModel> verifyEmailOtp(
    String email,
    String otp,
    String role,
  ) async {
    await _delay();
    if (otp != MockData.demoOtp) {
      throw const AuthCredentialsException('auth_invalid_otp');
    }
    return _mockAuthUser(role: role, phone: email);
  }

  Future<AuthUserModel> loginWithEmailPassword(
    String email,
    String password,
    String role,
  ) async {
    await _delay();
    if (role == 'waiter' || role == 'kitchenStaff') {
      final normalized = email.trim().toLowerCase();
      AdminUserModel? match;
      for (final user in _adminUsers) {
        if (user.role == role &&
            user.isActive &&
            user.username?.toLowerCase() == normalized &&
            user.password == password) {
          match = user;
          break;
        }
      }
      if (match == null) {
        throw const AuthCredentialsException('auth_invalid_credentials');
      }
      return AuthUserModel(
        id: match.id,
        name: match.name,
        role: match.role,
        phone: match.phone,
        branchId: match.branchId,
        username: match.username,
        accessToken: 'mock_token',
        refreshToken: 'mock_refresh',
      );
    }
    if (password != MockData.demoPassword) {
      throw const AuthCredentialsException('auth_invalid_credentials');
    }
    return _mockAuthUser(role: role, phone: email);
  }

  Future<void> registerPushToken(String token) async => _delay();

  Future<Coupon?> getCoupon(String code) async {
    await _delay();
    final normalized = code.trim().toUpperCase();
    for (final coupon in MockData.coupons) {
      if (coupon.code.toUpperCase() == normalized) return coupon;
    }
    return null;
  }

  Future<List<Branch>> getAdminBranches() async => getBranches();

  Future<List<AdminUserModel>> getAdminUsers() async {
    await _delay();
    return List.of(_adminUsers);
  }

  Future<PaytrInitModel> initPaytr(PaytrInitRequest request) async {
    await _delay();
    return PaytrInitModel(
      merchantOid: request.merchantOid,
      iframeToken: 'demo_paytr_token',
      iframeUrl: 'asset:///assets/paytr/demo_checkout.html',
    );
  }

  Future<PaymentResult> verifyPaytr(String merchantOid, double amount) async {
    await _delay();
    return PaymentResult(
      transactionId: 'paytr_demo_$merchantOid',
      amount: amount,
    );
  }

  Future<AdminUserModel> createAdminUser(AdminUserModel user) async {
    await _delay();
    _adminUsers = [..._adminUsers, user];
    return user;
  }

  Future<AdminUserModel> updateAdminUser(AdminUserModel user) async {
    await _delay();
    _adminUsers = [
      for (final u in _adminUsers) if (u.id == user.id) user else u,
    ];
    return user;
  }

  Future<void> deleteAdminUser(String userId) async {
    await _delay();
    _adminUsers = _adminUsers.where((u) => u.id != userId).toList();
  }

  Future<AdminReportModel> getAdminReports() async {
    await _delay();
    final revenue = _orders.fold<double>(0, (s, o) => s + o.totalAmount);
    return AdminReportModel(
      totalRevenue: revenue,
      totalOrders: _orders.length,
      activeBranches: _branches.length,
    );
  }

  Order buildNewOrder({
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
  }) {
    _orderCounter++;
    final branch = _branches.firstWhere(
      (b) => b.id == branchId,
      orElse: () => _branches.first,
    );
    final deliveryLat = deliveryLatitude ?? branch.latitude + 0.012;
    final deliveryLng = deliveryLongitude ?? branch.longitude + 0.008;

    return Order(
      id: 'order_$_orderCounter',
      orderNumber: _orderCounter,
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
      deliveryLatitude: deliveryLat,
      deliveryLongitude: deliveryLng,
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

  Order buildDineInOrder({
    required List<CartItem> items,
    required double totalAmount,
    required String branchId,
    required int tableNumber,
    required String waiterId,
    required String waiterName,
    String? waiterCode,
    String? orderNote,
    List<String> preparationTags = const [],
  }) {
    _orderCounter++;
    final now = DateTime.now();
    return Order(
      id: 'order_$_orderCounter',
      orderNumber: _orderCounter,
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

  final List<ProductReview> _productReviews = [];
  final _reviewChanges = StreamController<void>.broadcast();

  Stream<void> get reviewChanges => _reviewChanges.stream;

  void _notifyReviewChange() {
    if (!_reviewChanges.isClosed) {
      _reviewChanges.add(null);
    }
  }

  Future<List<ProductReview>> getCustomerProductReviews(String customerId) async {
    await _delay();
    return _productReviews
        .where((r) => r.customerId == customerId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<ProductReview>> getApprovedProductReviews(String productId) async {
    await _delay();
    return _productReviews
        .where((r) => r.productId == productId && r.isApproved)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<List<ProductReview>> getPendingProductReviews() async {
    await _delay();
    return _productReviews.where((r) => !r.isApproved).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<ProductReview> submitProductReview(ProductReview review) async {
    await _delay();
    _productReviews.insert(0, review);
    _notifyReviewChange();
    return review;
  }

  Future<ProductReview> approveProductReview(String reviewId) async {
    await _delay();
    final index = _productReviews.indexWhere((r) => r.id == reviewId);
    final updated = _productReviews[index].copyWith(isApproved: true);
    _productReviews[index] = updated;

    final orderId = updated.orderId;
    if (orderId != null) {
      final orderIndex = _orders.indexWhere((o) => o.id == orderId);
      if (orderIndex >= 0) {
        _orders[orderIndex] = _orders[orderIndex].copyWith(
          rating: updated.rating,
          ratingComment: updated.comment.isEmpty ? null : updated.comment,
        );
      }
    }

    _notifyReviewChange();
    return updated;
  }

  Future<void> rejectProductReview(String reviewId) async {
    await _delay();
    _productReviews.removeWhere((r) => r.id == reviewId);
    _notifyReviewChange();
  }

  Future<WaiterModeSettings> getWaiterModeSettings() async {
    await _delay();
    return _waiterModeSettings;
  }

  Future<WaiterModeSettings> updateWaiterModeSettings(
    WaiterModeSettings settings,
  ) async {
    await _delay();
    _waiterModeSettings = settings.copyWith(
      tableCount: settings.tableCount.clamp(1, 99),
    );
    return _waiterModeSettings;
  }

  Stream<WaiterModeSettings> watchWaiterModeSettings() async* {
    yield _waiterModeSettings;
  }

  Future<PrintRoutingSettings> getPrintRoutingSettings() async {
    await _delay();
    return _printRoutingSettings;
  }

  Future<PrintRoutingSettings> updatePrintRoutingSettings(
    PrintRoutingSettings settings,
  ) async {
    await _delay();
    _printRoutingSettings = settings;
    return _printRoutingSettings;
  }

  Stream<PrintRoutingSettings> watchPrintRoutingSettings() async* {
    yield _printRoutingSettings;
  }

  Future<PaytrSettings> getPaytrSettings() async {
    await _delay();
    return _paytrSettings;
  }

  Future<PaytrSettings> updatePaytrSettings(PaytrSettings settings) async {
    await _delay();
    _paytrSettings = settings;
    return _paytrSettings;
  }

  Stream<PaytrSettings> watchPaytrSettings() async* {
    yield _paytrSettings;
  }

  Future<DeliverySettings> getDeliverySettings() async {
    await _delay();
    return _deliverySettings;
  }

  Future<DeliverySettings> updateDeliverySettings(
    DeliverySettings settings,
  ) async {
    await _delay();
    _deliverySettings = settings.copyWith(
      freeDeliveryMinOrder: settings.freeDeliveryMinOrder.clamp(0, 100000),
    );
    return _deliverySettings;
  }

  Stream<DeliverySettings> watchDeliverySettings() async* {
    yield _deliverySettings;
  }

  Future<List<PromotionCampaign>> getPromotionCampaigns() async {
    await _delay();
    return List<PromotionCampaign>.of(_promotions)
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Stream<List<PromotionCampaign>> watchPromotionCampaigns() async* {
    yield await getPromotionCampaigns();
  }

  Future<PromotionCampaign?> getPromotionByCode(String code) async {
    await _delay();
    final normalized = code.trim().toUpperCase();
    for (final promo in _promotions) {
      if (promo.normalizedCode == normalized && promo.isActive) {
        return promo;
      }
    }
    return null;
  }

  Future<PromotionCampaign> createPromotionCampaign(
    PromotionCampaign campaign,
  ) async {
    await _delay();
    _promotions = [..._promotions, campaign];
    return campaign;
  }

  Future<PromotionCampaign> updatePromotionCampaign(
    PromotionCampaign campaign,
  ) async {
    await _delay();
    _promotions = [
      for (final item in _promotions)
        if (item.id == campaign.id) campaign else item,
    ];
    return campaign;
  }

  Future<void> deletePromotionCampaign(String id) async {
    await _delay();
    _promotions = _promotions.where((item) => item.id != id).toList();
  }

  Future<void> _delay() =>
      Future<void>.delayed(const Duration(milliseconds: 50));
}
