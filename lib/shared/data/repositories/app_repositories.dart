import 'dart:async';

import '../../../core/config/app_config.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/coupon.dart';
import '../../domain/entities/order.dart';
import '../../../core/media/media_storage_service.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_extra.dart';
import '../../domain/entities/product_review.dart';
import '../../domain/utils/product_extras_resolver.dart';
import '../../domain/entities/auth.dart';
import '../../domain/entities/waiter_mode_settings.dart';
import '../../domain/entities/paytr_settings.dart';
import '../../domain/entities/print_routing_settings.dart';
import '../../domain/entities/delivery_settings.dart';
import '../../domain/entities/promotion_campaign.dart';
import '../datasources/firestore/firestore_datasource.dart';
import '../datasources/mock_api_datasource.dart';
import '../datasources/remote/remote_datasources.dart';
import '../mappers/entity_mappers.dart';
import '../mock/mock_data.dart';
import '../models/api_models.dart';

class BranchRepository {
  BranchRepository({
    required BranchRemoteDataSource remote,
    required MockApiDataSource mock,
    required FirestoreDataSource firestore,
  })  : _remote = remote,
        _mock = mock,
        _firestore = firestore;

  final BranchRemoteDataSource _remote;
  final MockApiDataSource _mock;
  final FirestoreDataSource _firestore;

  Future<List<Branch>> getBranches() async {
    if (AppConfig.useMockApi) return _mock.getBranches();
    if (AppConfig.useFirestore) {
      try {
        await _firestore.ensureSeeded();
        final branches = await _firestore.getBranches();
        if (branches.isEmpty) return _mock.getBranches();
        return branches;
      } catch (_) {
        return _mock.getBranches();
      }
    }
    try {
      final models = await _remote.getBranches();
      return models.map(EntityMappers.toBranch).toList();
    } catch (_) {
      return _mock.getBranches();
    }
  }
}

class ProductRepository {
  ProductRepository({
    required ProductRemoteDataSource remote,
    required MockApiDataSource mock,
    required FirestoreDataSource firestore,
  })  : _remote = remote,
        _mock = mock,
        _firestore = firestore;

  final ProductRemoteDataSource _remote;
  final MockApiDataSource _mock;
  final FirestoreDataSource _firestore;

  Future<List<ProductExtra>> _loadCatalogExtras() async {
    List<ProductExtra> extras;
    if (AppConfig.useMockApi) {
      extras = await _mock.getCatalogExtras();
    } else if (AppConfig.useFirestoreBackend) {
      try {
        extras = await _firestore
            .getCatalogExtras()
            .timeout(AppConfig.apiTimeout);
        if (extras.isEmpty) {
          extras = await _mock.getCatalogExtras();
        }
      } catch (_) {
        extras = await _mock.getCatalogExtras();
      }
    } else {
      extras = await _mock.getCatalogExtras();
    }
    return _migrateLocalExtraImages(extras);
  }

  Future<List<ProductExtra>> _migrateLocalExtraImages(
    List<ProductExtra> extras,
  ) async {
    if (!AppConfig.useFirestore) return extras;

    final migrated = <ProductExtra>[];
    for (final extra in extras) {
      final prepared = await _prepareExtraForRemote(extra);
      if (prepared.imageUrl != extra.imageUrl &&
          MediaStorageService.isBase64Source(prepared.imageUrl ?? '')) {
        try {
          await _firestore.updateCatalogExtra(prepared);
        } catch (_) {}
      }
      migrated.add(prepared);
    }
    return migrated;
  }

  Future<List<Product>> _resolveProducts(List<Product> products) async {
    final catalog = await _loadCatalogExtras();
    final resolved = <Product>[];
    for (final product in products) {
      var normalized = await _normalizeProductImage(product);
      normalized = ProductExtrasResolver.withResolvedExtras(
        normalized,
        catalog,
        fallbackExtraIds: MockData.defaultProductExtraIds,
      );
      resolved.add(normalized);
    }
    return resolved;
  }

  Future<Product> _normalizeProductImage(Product product) async {
    var imageUrl = product.imageUrl;
    if (imageUrl != null &&
        !MediaStorageService.isNetworkSource(imageUrl) &&
        !MediaStorageService.isBase64Source(imageUrl) &&
        !MediaStorageService.localFileExists(imageUrl)) {
      imageUrl = MockData.imageUrlForProduct(product.id);
    }
    if (imageUrl == product.imageUrl) return product;
    return product.copyWith(imageUrl: imageUrl);
  }

  Future<ProductExtra> _normalizeExtraImage(ProductExtra extra) async {
    var imageUrl = extra.imageUrl;
    if (imageUrl != null &&
        !MediaStorageService.isNetworkSource(imageUrl) &&
        !MediaStorageService.isBase64Source(imageUrl) &&
        !MediaStorageService.localFileExists(imageUrl)) {
      imageUrl = MockData.imageUrlForExtra(extra.id);
    }
    if (imageUrl == extra.imageUrl) return extra;
    return extra.copyWith(imageUrl: imageUrl);
  }

  Future<Product> _prepareProductForRemote(Product product) async {
    final imageUrl =
        await MediaStorageService.ensureRemoteReady(product.imageUrl);
    if (imageUrl == product.imageUrl) return product;
    return product.copyWith(imageUrl: imageUrl);
  }

  Future<List<Product>> _migrateLocalProductImages(List<Product> products) async {
    final migrated = <Product>[];
    for (final product in products) {
      final prepared = await _prepareProductForRemote(product);
      if (prepared.imageUrl != product.imageUrl &&
          MediaStorageService.isBase64Source(prepared.imageUrl ?? '')) {
        try {
          await _firestore.updateProduct(prepared);
        } catch (_) {}
      }
      migrated.add(prepared);
    }
    return migrated;
  }

  Future<ProductExtra> _prepareExtraForRemote(ProductExtra extra) async {
    final imageUrl =
        await MediaStorageService.ensureRemoteReady(extra.imageUrl);
    if (imageUrl == extra.imageUrl) return extra;
    return extra.copyWith(imageUrl: imageUrl);
  }

  Future<List<ProductExtra>> getCatalogExtras() async {
    final extras = await _loadCatalogExtras();
    final normalized = <ProductExtra>[];
    for (final extra in extras) {
      normalized.add(await _normalizeExtraImage(extra));
    }
    return normalized;
  }

  Future<ProductExtra> createCatalogExtra(ProductExtra extra) async {
    extra = await _prepareExtraForRemote(extra);
    if (AppConfig.useMockApi) return _mock.createCatalogExtra(extra);
    if (AppConfig.useFirestore) {
      try {
        return await _firestore
            .createCatalogExtra(extra)
            .timeout(AppConfig.apiTimeout);
      } catch (_) {
        return _mock.createCatalogExtra(extra);
      }
    }
    return _mock.createCatalogExtra(extra);
  }

  Future<ProductExtra> updateCatalogExtra(ProductExtra extra) async {
    extra = await _prepareExtraForRemote(extra);
    if (AppConfig.useMockApi) return _mock.updateCatalogExtra(extra);
    if (AppConfig.useFirestore) {
      try {
        return await _firestore
            .updateCatalogExtra(extra)
            .timeout(AppConfig.apiTimeout);
      } catch (_) {
        return _mock.updateCatalogExtra(extra);
      }
    }
    return _mock.updateCatalogExtra(extra);
  }

  Future<void> deleteCatalogExtra(String extraId) async {
    if (AppConfig.useMockApi) return _mock.deleteCatalogExtra(extraId);
    if (AppConfig.useFirestore) {
      try {
        await _firestore.deleteCatalogExtra(extraId);
        return;
      } catch (_) {}
    }
    await _mock.deleteCatalogExtra(extraId);
  }

  Future<List<Product>> getProducts({String? branchId}) async {
    if (AppConfig.useMockApi) {
      return _resolveProducts(await _mock.getProducts(branchId: branchId));
    }
    if (AppConfig.useFirestore) {
      try {
        await _firestore.ensureSeeded();
        final products = await _firestore.getProducts(branchId: branchId);
        if (products.isEmpty) {
          return _resolveProducts(await _mock.getProducts(branchId: branchId));
        }
        final migrated = await _migrateLocalProductImages(products);
        return _resolveProducts(migrated);
      } catch (_) {
        return _resolveProducts(await _mock.getProducts(branchId: branchId));
      }
    }
    try {
      final models = await _remote.getProducts(branchId: branchId);
      return _resolveProducts(models.map(EntityMappers.toProduct).toList());
    } catch (_) {
      return _resolveProducts(await _mock.getProducts(branchId: branchId));
    }
  }

  Future<Product> toggleAvailability(String productId, bool available) async {
    Product updated;
    if (AppConfig.useMockApi) {
      updated = await _mock.updateProductAvailability(productId, available);
    } else if (AppConfig.useFirestore) {
      updated = await _firestore.updateProductAvailability(productId, available);
    } else {
      try {
        final model = await _remote.updateAvailability(productId, available);
        updated = EntityMappers.toProduct(model);
      } catch (_) {
        updated = await _mock.updateProductAvailability(productId, available);
      }
    }
    final catalog = await _loadCatalogExtras();
    return ProductExtrasResolver.withResolvedExtras(
      updated,
      catalog,
      fallbackExtraIds: MockData.defaultProductExtraIds,
    );
  }

  Future<Product> createProduct(Product product) async {
    product = await _prepareProductForRemote(product);
    Product created;
    if (AppConfig.useMockApi) {
      created = await _mock.createProduct(product);
    } else if (AppConfig.useFirestore) {
      try {
        created = await _firestore
            .createProduct(product)
            .timeout(AppConfig.apiTimeout);
      } catch (_) {
        created = await _mock.createProduct(product);
      }
    } else {
      try {
        final model =
            await _remote.createProduct(EntityMappers.fromProduct(product));
        created = EntityMappers.toProduct(model);
      } catch (_) {
        created = await _mock.createProduct(product);
      }
    }
    final catalog = await _loadCatalogExtras();
    return ProductExtrasResolver.withResolvedExtras(
      created,
      catalog,
      fallbackExtraIds: MockData.defaultProductExtraIds,
    );
  }

  Future<Product> updateProduct(Product product) async {
    product = await _prepareProductForRemote(product);
    Product updated;
    if (AppConfig.useMockApi) {
      updated = await _mock.updateProduct(product);
    } else if (AppConfig.useFirestore) {
      try {
        updated = await _firestore
            .updateProduct(product)
            .timeout(AppConfig.apiTimeout);
      } catch (_) {
        updated = await _mock.updateProduct(product);
      }
    } else {
      try {
        final model =
            await _remote.updateProduct(EntityMappers.fromProduct(product));
        updated = EntityMappers.toProduct(model);
      } catch (_) {
        updated = await _mock.updateProduct(product);
      }
    }
    final catalog = await _loadCatalogExtras();
    return ProductExtrasResolver.withResolvedExtras(
      updated,
      catalog,
      fallbackExtraIds: MockData.defaultProductExtraIds,
    );
  }

  Future<void> deleteProduct(String productId) async {
    if (AppConfig.useMockApi) return _mock.deleteProduct(productId);
    if (AppConfig.useFirestore) return _firestore.deleteProduct(productId);
    try {
      await _remote.deleteProduct(productId);
    } catch (_) {
      await _mock.deleteProduct(productId);
    }
  }
}

class CouponRepository {
  CouponRepository({required FirestoreDataSource firestore, required MockApiDataSource mock})
      : _firestore = firestore,
        _mock = mock;

  final FirestoreDataSource _firestore;
  final MockApiDataSource _mock;

  Future<Coupon?> getCoupon(String code) async {
    if (AppConfig.useMockApi) return _mock.getCoupon(code);
    if (AppConfig.useFirestore) return _firestore.getCoupon(code);
    return _mock.getCoupon(code);
  }
}

class OrderRepository {
  OrderRepository({
    required OrderRemoteDataSource remote,
    required MockApiDataSource mock,
    required FirestoreDataSource firestore,
  })  : _remote = remote,
        _mock = mock,
        _firestore = firestore;

  final OrderRemoteDataSource _remote;
  final MockApiDataSource _mock;
  final FirestoreDataSource _firestore;

  Stream<List<Order>> watchOrders() {
    if (AppConfig.useFirestoreBackend) return _firestore.watchOrders();
    return const Stream.empty();
  }

  Future<List<Order>> getOrders() async {
    if (AppConfig.useMockApi) return _mock.getOrders();
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.getOrders();
      } catch (_) {
        return _mock.getOrders();
      }
    }
    try {
      final models = await _remote.getOrders();
      return models.map(EntityMappers.toOrder).toList();
    } catch (_) {
      return _mock.getOrders();
    }
  }

  Future<Order> placeOrder(Order order) async {
    if (AppConfig.useMockApi) return _mock.createOrder(order);
    if (AppConfig.useFirestore) {
      try {
        await _firestore.ensureSeeded();
        return await _firestore
            .createOrder(order)
            .timeout(AppConfig.apiTimeout);
      } catch (_) {
        final saved = await _mock.createOrder(order);
        unawaited(_retryFirestoreOrder(order));
        return saved;
      }
    }
    try {
      final model = await _remote.createOrder(order);
      return EntityMappers.toOrder(model);
    } catch (_) {
      return _mock.createOrder(order);
    }
  }

  Future<void> _retryFirestoreOrder(Order order) async {
    try {
      await _firestore.ensureSeeded();
      await _firestore.createOrder(order).timeout(AppConfig.apiTimeout);
    } catch (_) {}
  }

  Future<Order> updateStatus(
    String orderId,
    OrderStatus status, {
    String? actorId,
    String? actorName,
  }) async {
    if (AppConfig.useMockApi) {
      return _mock.updateOrderStatus(
        orderId,
        status,
        actorId: actorId,
        actorName: actorName,
      );
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.updateOrderStatus(
        orderId,
        status,
        actorId: actorId,
        actorName: actorName,
      );
    }
    try {
      final model = await _remote.updateStatus(orderId, status);
      return EntityMappers.toOrder(model);
    } catch (_) {
      return _mock.updateOrderStatus(
        orderId,
        status,
        actorId: actorId,
        actorName: actorName,
      );
    }
  }

  Future<Order> assignCourier(
    String orderId,
    String courierId,
    String courierName, {
    String? actorId,
    String? actorName,
  }) async {
    if (AppConfig.useMockApi) {
      return _mock.assignCourier(
        orderId,
        courierId,
        courierName,
        actorId: actorId,
        actorName: actorName,
      );
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.assignCourier(
        orderId,
        courierId,
        courierName,
        actorId: actorId,
        actorName: actorName,
      );
    }
    try {
      final model =
          await _remote.assignCourier(orderId, courierId, courierName);
      return EntityMappers.toOrder(model);
    } catch (_) {
      return _mock.assignCourier(
        orderId,
        courierId,
        courierName,
        actorId: actorId,
        actorName: actorName,
      );
    }
  }

  Future<Order> updateCourierLocation(
    String orderId,
    double latitude,
    double longitude,
  ) async {
    if (AppConfig.useMockApi) {
      return _mock.updateCourierLocation(orderId, latitude, longitude);
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.updateCourierLocation(orderId, latitude, longitude);
    }
    return _mock.updateCourierLocation(orderId, latitude, longitude);
  }

  Future<Order> cancelOrder(
    String orderId, {
    String? actorId,
    String? actorName,
  }) async {
    if (AppConfig.useMockApi) {
      return _mock.cancelOrder(
        orderId,
        actorId: actorId,
        actorName: actorName,
      );
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.cancelOrder(
        orderId,
        actorId: actorId,
        actorName: actorName,
      );
    }
    try {
      final model = await _remote.cancelOrder(orderId);
      return EntityMappers.toOrder(model);
    } catch (_) {
      return _mock.cancelOrder(
        orderId,
        actorId: actorId,
        actorName: actorName,
      );
    }
  }

  Future<Order> markApproachNotificationSent(String orderId) async {
    if (AppConfig.useMockApi) {
      return _mock.markApproachNotificationSent(orderId);
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.markApproachNotificationSent(orderId);
    }
    return _mock.markApproachNotificationSent(orderId);
  }

  Future<Order> rateOrder(
    String orderId,
    int rating, {
    String? comment,
  }) async {
    if (AppConfig.useMockApi) {
      return _mock.rateOrder(orderId, rating, comment: comment);
    }
    if (AppConfig.useFirestore) {
      return _firestore.rateOrder(orderId, rating, comment: comment);
    }
    return _mock.rateOrder(orderId, rating, comment: comment);
  }

  Future<Order> buildOrder({
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
    if (AppConfig.useFirestore) {
      try {
        await _firestore.ensureSeeded();
        return await _firestore
            .buildNewOrderAsync(
              items: items,
              totalAmount: totalAmount,
              customerId: customerId,
              customerName: customerName,
              branchId: branchId,
              address: address,
              paymentMethod: paymentMethod,
              orderNote: orderNote,
              deliveryNow: deliveryNow,
              scheduledAt: scheduledAt,
              deliveryLatitude: deliveryLatitude,
              deliveryLongitude: deliveryLongitude,
              customerPhone: customerPhone,
              deliveryDirections: deliveryDirections,
              paymentTransactionId: paymentTransactionId,
              couponCode: couponCode,
              discountAmount: discountAmount,
              deliveryFeeAmount: deliveryFeeAmount,
              estimatedDeliveryMinutes: estimatedDeliveryMinutes,
            )
            .timeout(AppConfig.apiTimeout);
      } catch (_) {
        return _mock.buildNewOrder(
          items: items,
          totalAmount: totalAmount,
          customerId: customerId,
          customerName: customerName,
          branchId: branchId,
          address: address,
          paymentMethod: paymentMethod,
          orderNote: orderNote,
          deliveryNow: deliveryNow,
          scheduledAt: scheduledAt,
          deliveryLatitude: deliveryLatitude,
          deliveryLongitude: deliveryLongitude,
          customerPhone: customerPhone,
          deliveryDirections: deliveryDirections,
          paymentTransactionId: paymentTransactionId,
          couponCode: couponCode,
          discountAmount: discountAmount,
          deliveryFeeAmount: deliveryFeeAmount,
          estimatedDeliveryMinutes: estimatedDeliveryMinutes,
        );
      }
    }
    return _mock.buildNewOrder(
      items: items,
      totalAmount: totalAmount,
      customerId: customerId,
      customerName: customerName,
      branchId: branchId,
      address: address,
      paymentMethod: paymentMethod,
      orderNote: orderNote,
      deliveryNow: deliveryNow,
      scheduledAt: scheduledAt,
      deliveryLatitude: deliveryLatitude,
      deliveryLongitude: deliveryLongitude,
      customerPhone: customerPhone,
      deliveryDirections: deliveryDirections,
      paymentTransactionId: paymentTransactionId,
      couponCode: couponCode,
      discountAmount: discountAmount,
      deliveryFeeAmount: deliveryFeeAmount,
      estimatedDeliveryMinutes: estimatedDeliveryMinutes,
    );
  }

  Future<Order> placeDineInOrder({
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
    if (AppConfig.useFirestoreBackend) {
      final built = await _firestore.buildDineInOrderAsync(
        items: items,
        totalAmount: totalAmount,
        branchId: branchId,
        tableNumber: tableNumber,
        waiterId: waiterId,
        waiterName: waiterName,
        waiterCode: waiterCode,
        orderNote: orderNote,
        preparationTags: preparationTags,
      );
      return await _firestore
          .createOrder(built)
          .timeout(AppConfig.apiTimeout);
    }
    final built = _mock.buildDineInOrder(
      items: items,
      totalAmount: totalAmount,
      branchId: branchId,
      tableNumber: tableNumber,
      waiterId: waiterId,
      waiterName: waiterName,
      waiterCode: waiterCode,
      orderNote: orderNote,
      preparationTags: preparationTags,
    );
    return _mock.createOrder(built);
  }

  Future<List<Order>> closeDineInTableBill({
    required String branchId,
    required int tableNumber,
    required PaymentMethod paymentMethod,
    String? paymentTransactionId,
    String? actorId,
    String? actorName,
  }) async {
    if (AppConfig.useMockApi) {
      return _mock.closeDineInTableBill(
        branchId: branchId,
        tableNumber: tableNumber,
        paymentMethod: paymentMethod,
        paymentTransactionId: paymentTransactionId,
        actorId: actorId,
        actorName: actorName,
      );
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.closeDineInTableBill(
        branchId: branchId,
        tableNumber: tableNumber,
        paymentMethod: paymentMethod,
        paymentTransactionId: paymentTransactionId,
        actorId: actorId,
        actorName: actorName,
      );
    }
    return _mock.closeDineInTableBill(
      branchId: branchId,
      tableNumber: tableNumber,
      paymentMethod: paymentMethod,
      paymentTransactionId: paymentTransactionId,
      actorId: actorId,
      actorName: actorName,
    );
  }

  Future<List<Order>> voidDineInTableBill({
    required String branchId,
    required int tableNumber,
    String? actorId,
    String? actorName,
  }) async {
    if (AppConfig.useMockApi) {
      return _mock.voidDineInTableBill(
        branchId: branchId,
        tableNumber: tableNumber,
        actorId: actorId,
        actorName: actorName,
      );
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.voidDineInTableBill(
        branchId: branchId,
        tableNumber: tableNumber,
        actorId: actorId,
        actorName: actorName,
      );
    }
    return _mock.voidDineInTableBill(
      branchId: branchId,
      tableNumber: tableNumber,
      actorId: actorId,
      actorName: actorName,
    );
  }

  Future<Order> removeDineInOrderItem(
    String orderId,
    String cartItemId, {
    int quantity = 1,
    String? actorId,
    String? actorName,
  }) async {
    if (AppConfig.useMockApi) {
      return _mock.removeDineInOrderItem(
        orderId,
        cartItemId,
        quantity: quantity,
        actorId: actorId,
        actorName: actorName,
      );
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.removeDineInOrderItem(
        orderId,
        cartItemId,
        quantity: quantity,
        actorId: actorId,
        actorName: actorName,
      );
    }
    return _mock.removeDineInOrderItem(
      orderId,
      cartItemId,
      quantity: quantity,
      actorId: actorId,
      actorName: actorName,
    );
  }
}

class AuthRepository {
  AuthRepository({
    required AuthRemoteDataSource remote,
    required MockApiDataSource mock,
    required FirestoreDataSource firestore,
  })  : _remote = remote,
        _mock = mock,
        _firestore = firestore;

  final AuthRemoteDataSource _remote;
  final MockApiDataSource _mock;
  final FirestoreDataSource _firestore;

  Future<void> sendOtp(String phone, String role) async {
    if (AppConfig.useMockApi) return _mock.sendOtp(phone, role);
    if (AppConfig.useFirestore) return _firestore.sendOtp(phone, role);
    try {
      await _remote.sendOtp(phone, role);
    } catch (_) {
      await _mock.sendOtp(phone, role);
    }
  }

  Future<void> sendEmailOtp(String email, String role) async {
    if (AppConfig.useMockApi) return _mock.sendEmailOtp(email, role);
    if (AppConfig.useFirestore) return _firestore.sendEmailOtp(email, role);
    try {
      await _remote.sendEmailOtp(email, role);
    } catch (_) {
      await _mock.sendEmailOtp(email, role);
    }
  }

  Future<AuthUserModel> verifyOtp(String phone, String otp, String role) async {
    if (AppConfig.useMockApi) return _mock.verifyOtp(phone, otp, role);
    if (AppConfig.useFirestore) return _firestore.verifyOtp(phone, otp, role);
    try {
      return await _remote.verifyOtp(phone, otp, role);
    } catch (_) {
      return _mock.verifyOtp(phone, otp, role);
    }
  }

  Future<AuthUserModel> verifyEmailOtp(
    String email,
    String otp,
    String role,
  ) async {
    if (AppConfig.useMockApi) return _mock.verifyEmailOtp(email, otp, role);
    if (AppConfig.useFirestore) return _firestore.verifyEmailOtp(email, otp, role);
    try {
      return await _remote.verifyEmailOtp(email, otp, role);
    } catch (_) {
      return _mock.verifyEmailOtp(email, otp, role);
    }
  }

  Future<AuthUserModel> loginWithEmailPassword(
    String email,
    String password,
    String role,
  ) async {
    if (AppConfig.useMockApi) {
      return _mock.loginWithEmailPassword(email, password, role);
    }
    if (AppConfig.useFirestore || AppConfig.useWindowsOpsFirestoreRest) {
      try {
        return await _firestore.loginWithEmailPassword(email, password, role);
      } on AuthCredentialsException {
        // Firestore'da ops kullanıcısı yoksa demo garson/mutfak hesaplarına düş.
        if (role == 'waiter' || role == 'kitchenStaff') {
          return _mock.loginWithEmailPassword(email, password, role);
        }
        rethrow;
      }
    }
    try {
      return await _remote.loginWithEmailPassword(email, password, role);
    } on AuthCredentialsException {
      rethrow;
    } catch (_) {
      return _mock.loginWithEmailPassword(email, password, role);
    }
  }

  Future<void> registerPushToken(
    String token, {
    required String userId,
    required String role,
    String? branchId,
  }) async {
    if (AppConfig.useMockApi) return _mock.registerPushToken(token);
    if (AppConfig.useFirestore) {
      return _firestore.registerPushToken(
        token,
        userId: userId,
        role: role,
        branchId: branchId,
      );
    }
    try {
      await _remote.registerPushToken(token);
    } catch (_) {
      await _mock.registerPushToken(token);
    }
  }
}

class AdminRepository {
  AdminRepository({
    required AdminRemoteDataSource remote,
    required MockApiDataSource mock,
    required FirestoreDataSource firestore,
  })  : _remote = remote,
        _mock = mock,
        _firestore = firestore;

  final AdminRemoteDataSource _remote;
  final MockApiDataSource _mock;
  final FirestoreDataSource _firestore;

  Future<List<Branch>> getBranches() async {
    if (AppConfig.useMockApi) return _mock.getAdminBranches();
    if (AppConfig.useFirestore) {
      try {
        return await _firestore.getBranches();
      } catch (_) {
        return _mock.getAdminBranches();
      }
    }
    try {
      final models = await _remote.getBranches();
      return models.map(EntityMappers.toBranch).toList();
    } catch (_) {
      return _mock.getAdminBranches();
    }
  }

  Future<List<AdminUserModel>> getUsers() async {
    if (AppConfig.useMockApi) return _mock.getAdminUsers();
    if (AppConfig.useFirestore) {
      try {
        return await _firestore.getAdminUsers();
      } catch (_) {
        return _mock.getAdminUsers();
      }
    }
    try {
      return await _remote.getUsers();
    } catch (_) {
      return _mock.getAdminUsers();
    }
  }

  Future<AdminReportModel> getReports() async {
    if (AppConfig.useMockApi) return _mock.getAdminReports();
    if (AppConfig.useFirestore) {
      try {
        return await _firestore.getAdminReports();
      } catch (_) {
        return _mock.getAdminReports();
      }
    }
    try {
      return await _remote.getReports();
    } catch (_) {
      return _mock.getAdminReports();
    }
  }

  Future<Branch> createBranch(Branch branch) async {
    if (AppConfig.useMockApi) return _mock.createBranch(branch);
    if (AppConfig.useFirestore) return _firestore.createBranch(branch);
    try {
      final model =
          await _remote.createBranch(EntityMappers.fromBranch(branch));
      return EntityMappers.toBranch(model);
    } catch (_) {
      return _mock.createBranch(branch);
    }
  }

  Future<Branch> updateBranch(Branch branch) async {
    if (AppConfig.useMockApi) return _mock.updateBranch(branch);
    if (AppConfig.useFirestore) return _firestore.updateBranch(branch);
    try {
      final model =
          await _remote.updateBranch(EntityMappers.fromBranch(branch));
      return EntityMappers.toBranch(model);
    } catch (_) {
      return _mock.updateBranch(branch);
    }
  }

  Future<void> deleteBranch(String branchId) async {
    if (AppConfig.useMockApi) return _mock.deleteBranch(branchId);
    if (AppConfig.useFirestore) return _firestore.deleteBranch(branchId);
    try {
      await _remote.deleteBranch(branchId);
    } catch (_) {
      await _mock.deleteBranch(branchId);
    }
  }

  Future<AdminUserModel> createUser(AdminUserModel user) async {
    if (AppConfig.useMockApi) return _mock.createAdminUser(user);
    if (AppConfig.useFirestore) return _firestore.createAdminUser(user);
    try {
      return await _remote.createUser(user);
    } catch (_) {
      return _mock.createAdminUser(user);
    }
  }

  Future<AdminUserModel> updateUser(AdminUserModel user) async {
    if (AppConfig.useMockApi) return _mock.updateAdminUser(user);
    if (AppConfig.useFirestore) return _firestore.updateAdminUser(user);
    try {
      return await _remote.updateUser(user);
    } catch (_) {
      return _mock.updateAdminUser(user);
    }
  }

  Future<void> deleteUser(String userId) async {
    if (AppConfig.useMockApi) return _mock.deleteAdminUser(userId);
    if (AppConfig.useFirestore) return _firestore.deleteAdminUser(userId);
    try {
      await _remote.deleteUser(userId);
    } catch (_) {
      await _mock.deleteAdminUser(userId);
    }
  }

  Future<WaiterModeSettings> getWaiterModeSettings() async {
    if (AppConfig.useMockApi) return _mock.getWaiterModeSettings();
    if (AppConfig.useFirestore) {
      try {
        return await _firestore.getWaiterModeSettings();
      } catch (_) {
        return _mock.getWaiterModeSettings();
      }
    }
    return WaiterModeSettings.defaults;
  }

  Future<WaiterModeSettings> updateWaiterModeSettings(
    WaiterModeSettings settings,
  ) async {
    if (AppConfig.useMockApi) {
      return _mock.updateWaiterModeSettings(settings);
    }
    if (AppConfig.useFirestore) {
      return _firestore.updateWaiterModeSettings(settings);
    }
    return _mock.updateWaiterModeSettings(settings);
  }

  Stream<WaiterModeSettings> watchWaiterModeSettings() {
    if (AppConfig.useMockApi) {
      return _mock.watchWaiterModeSettings();
    }
    if (AppConfig.useFirestore) {
      try {
        return _firestore.watchWaiterModeSettings();
      } catch (_) {
        return _mock.watchWaiterModeSettings();
      }
    }
    return Stream.value(WaiterModeSettings.defaults);
  }

  Future<PrintRoutingSettings> getPrintRoutingSettings() async {
    if (AppConfig.useMockApi) return _mock.getPrintRoutingSettings();
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.getPrintRoutingSettings();
      } catch (_) {
        return _mock.getPrintRoutingSettings();
      }
    }
    return PrintRoutingSettings.defaults;
  }

  Future<PrintRoutingSettings> updatePrintRoutingSettings(
    PrintRoutingSettings settings,
  ) async {
    if (AppConfig.useMockApi) {
      return _mock.updatePrintRoutingSettings(settings);
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.updatePrintRoutingSettings(settings);
    }
    return _mock.updatePrintRoutingSettings(settings);
  }

  Stream<PrintRoutingSettings> watchPrintRoutingSettings() {
    if (AppConfig.useMockApi) {
      return _mock.watchPrintRoutingSettings();
    }
    if (AppConfig.useFirestoreBackend) {
      try {
        return _firestore.watchPrintRoutingSettings();
      } catch (_) {
        return _mock.watchPrintRoutingSettings();
      }
    }
    return Stream.value(PrintRoutingSettings.defaults);
  }

  Future<PaytrSettings> getPaytrSettings() async {
    if (AppConfig.useMockApi) return _mock.getPaytrSettings();
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.getPaytrSettings();
      } catch (_) {
        return _mock.getPaytrSettings();
      }
    }
    return PaytrSettings.defaults;
  }

  Future<PaytrSettings> updatePaytrSettings(PaytrSettings settings) async {
    if (AppConfig.useMockApi) {
      return _mock.updatePaytrSettings(settings);
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.updatePaytrSettings(settings);
    }
    return _mock.updatePaytrSettings(settings);
  }

  Stream<PaytrSettings> watchPaytrSettings() {
    if (AppConfig.useMockApi) {
      return _mock.watchPaytrSettings();
    }
    if (AppConfig.useFirestoreBackend) {
      try {
        return _firestore.watchPaytrSettings();
      } catch (_) {
        return _mock.watchPaytrSettings();
      }
    }
    return Stream.value(PaytrSettings.defaults);
  }

  Future<DeliverySettings> getDeliverySettings() async {
    if (AppConfig.useMockApi) return _mock.getDeliverySettings();
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.getDeliverySettings();
      } catch (_) {
        return _mock.getDeliverySettings();
      }
    }
    return DeliverySettings.defaults;
  }

  Future<DeliverySettings> updateDeliverySettings(
    DeliverySettings settings,
  ) async {
    if (AppConfig.useMockApi) {
      return _mock.updateDeliverySettings(settings);
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.updateDeliverySettings(settings);
    }
    return _mock.updateDeliverySettings(settings);
  }

  Stream<DeliverySettings> watchDeliverySettings() {
    if (AppConfig.useMockApi) {
      return _mock.watchDeliverySettings();
    }
    if (AppConfig.useFirestoreBackend) {
      try {
        return _firestore.watchDeliverySettings();
      } catch (_) {
        return _mock.watchDeliverySettings();
      }
    }
    return Stream.value(DeliverySettings.defaults);
  }
}

class PromotionRepository {
  PromotionRepository({
    required MockApiDataSource mock,
    required FirestoreDataSource firestore,
  })  : _mock = mock,
        _firestore = firestore;

  final MockApiDataSource _mock;
  final FirestoreDataSource _firestore;

  Future<List<PromotionCampaign>> getPromotionCampaigns() async {
    if (AppConfig.useMockApi) return _mock.getPromotionCampaigns();
    if (AppConfig.useFirestore) {
      try {
        return await _firestore.getPromotionCampaigns();
      } catch (_) {}
    }
    return _mock.getPromotionCampaigns();
  }

  Stream<List<PromotionCampaign>> watchPromotionCampaigns() {
    if (AppConfig.useMockApi) {
      return _mock.watchPromotionCampaigns();
    }
    if (AppConfig.useFirestore) {
      try {
        return _firestore.watchPromotionCampaigns();
      } catch (_) {
        return _mock.watchPromotionCampaigns();
      }
    }
    return Stream.value(const []);
  }

  Future<PromotionCampaign?> getPromotionByCode(String code) async {
    if (AppConfig.useMockApi) return _mock.getPromotionByCode(code);
    if (AppConfig.useFirestore) {
      try {
        return await _firestore.getPromotionByCode(code);
      } catch (_) {}
    }
    return _mock.getPromotionByCode(code);
  }

  Future<PromotionCampaign> createPromotionCampaign(
    PromotionCampaign campaign,
  ) async {
    if (AppConfig.useMockApi) {
      return _mock.createPromotionCampaign(campaign);
    }
    if (AppConfig.useFirestore) {
      return _firestore.createPromotionCampaign(campaign);
    }
    return _mock.createPromotionCampaign(campaign);
  }

  Future<PromotionCampaign> updatePromotionCampaign(
    PromotionCampaign campaign,
  ) async {
    if (AppConfig.useMockApi) {
      return _mock.updatePromotionCampaign(campaign);
    }
    if (AppConfig.useFirestore) {
      return _firestore.updatePromotionCampaign(campaign);
    }
    return _mock.updatePromotionCampaign(campaign);
  }

  Future<void> deletePromotionCampaign(String id) async {
    if (AppConfig.useMockApi) {
      await _mock.deletePromotionCampaign(id);
      return;
    }
    if (AppConfig.useFirestore) {
      await _firestore.deletePromotionCampaign(id);
      return;
    }
    await _mock.deletePromotionCampaign(id);
  }
}

class ProductReviewRepository {
  ProductReviewRepository({
    required MockApiDataSource mock,
    required FirestoreDataSource firestore,
  })  : _mock = mock,
        _firestore = firestore;

  final MockApiDataSource _mock;
  final FirestoreDataSource _firestore;

  Future<List<ProductReview>> getCustomerReviews(String customerId) async {
    if (AppConfig.useFirestore) {
      try {
        return await _firestore.getCustomerProductReviews(customerId);
      } catch (_) {}
    }
    return _mock.getCustomerProductReviews(customerId);
  }

  Future<List<ProductReview>> getApprovedReviews(String productId) async {
    if (AppConfig.useFirestore) {
      try {
        return await _firestore.getApprovedProductReviews(productId);
      } catch (_) {}
    }
    return _mock.getApprovedProductReviews(productId);
  }

  Future<List<ProductReview>> getPendingReviews() async {
    if (AppConfig.useFirestore) {
      return _firestore.getPendingProductReviews();
    }
    return _mock.getPendingProductReviews();
  }

  Stream<List<ProductReview>> watchPendingReviews() {
    if (AppConfig.useFirestore) {
      return _firestore.watchPendingProductReviews();
    }
    return _mockPendingReviewStream();
  }

  Stream<List<ProductReview>> _mockPendingReviewStream() async* {
    yield await _mock.getPendingProductReviews();
    await for (final _ in _mock.reviewChanges) {
      yield await _mock.getPendingProductReviews();
    }
  }

  Future<ProductReview> submitReview(ProductReview review) async {
    if (AppConfig.useFirestore) {
      try {
        return await _firestore.submitProductReview(review);
      } catch (_) {}
    }
    return _mock.submitProductReview(review);
  }

  Future<ProductReview> approveReview(String reviewId) async {
    if (AppConfig.useFirestore) {
      try {
        return await _firestore.approveProductReview(reviewId);
      } catch (_) {}
    }
    return _mock.approveProductReview(reviewId);
  }

  Future<void> rejectReview(String reviewId) async {
    if (AppConfig.useFirestore) {
      try {
        await _firestore.rejectProductReview(reviewId);
        return;
      } catch (_) {}
    }
    await _mock.rejectProductReview(reviewId);
  }
}
