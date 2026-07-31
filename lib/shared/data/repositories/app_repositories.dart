import 'dart:async';

import '../../../core/config/app_config.dart';
import '../../../core/utils/customer_order_matching.dart';
import '../../../core/utils/phone_digits.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/delivery_address.dart';
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
import '../../domain/entities/qr_menu_settings.dart';
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
    if (AppConfig.useFirestoreBackend) {
      try {
        if (AppConfig.useFirestore) await _firestore.ensureSeeded();
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
        // Windows ops: asla mock kataloga düşme — eklenen görseller/ürünler kaybolmasın.
        if (extras.isEmpty && !AppConfig.useWindowsOpsFirestoreRest) {
          extras = await _mock.getCatalogExtras();
        }
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
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
    if (!AppConfig.useFirestoreBackend) return extras;

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
      // Yabancı cihaz yolu: Firestore kaydını silme; sadece gösterimde seed URL dene.
      final seed = MockData.imageUrlForProduct(product.id);
      if (seed != null && seed.isNotEmpty) {
        imageUrl = seed;
      }
      // Yerel path çözülemiyorsa olduğu gibi bırak (AppImage placeholder gösterir).
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
      final seed = MockData.imageUrlForExtra(extra.id);
      if (seed != null && seed.isNotEmpty) {
        imageUrl = seed;
      }
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
    if (!AppConfig.useFirestoreBackend) return products;
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

  Future<void> _clearWaiterCatalogPriceOverride(
    String itemId, {
    required bool isExtra,
  }) async {
    if (AppConfig.useMockApi || !AppConfig.useFirestoreBackend) return;
    try {
      final current = await _firestore.getWaiterModeSettings();
      final productPrices = Map<String, double>.from(current.productPrices);
      final catalogExtraPrices =
          Map<String, double>.from(current.catalogExtraPrices);
      final changed = isExtra
          ? catalogExtraPrices.remove(itemId) != null
          : productPrices.remove(itemId) != null;
      if (!changed) return;
      await _firestore.updateWaiterModeSettings(
        current.copyWith(
          productPrices: productPrices,
          catalogExtraPrices: catalogExtraPrices,
        ),
      );
    } catch (_) {}
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
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore
            .createCatalogExtra(extra)
            .timeout(AppConfig.apiTimeout);
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
        return _mock.createCatalogExtra(extra);
      }
    }
    return _mock.createCatalogExtra(extra);
  }

  Future<ProductExtra> updateCatalogExtra(ProductExtra extra) async {
    extra = await _prepareExtraForRemote(extra);
    if (AppConfig.useMockApi) return _mock.updateCatalogExtra(extra);
    if (AppConfig.useFirestoreBackend) {
      try {
        final updated = await _firestore
            .updateCatalogExtra(extra)
            .timeout(AppConfig.apiTimeout);
        await _clearWaiterCatalogPriceOverride(extra.id, isExtra: true);
        return updated;
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
        return _mock.updateCatalogExtra(extra);
      }
    }
    return _mock.updateCatalogExtra(extra);
  }

  Future<void> deleteCatalogExtra(String extraId) async {
    if (AppConfig.useMockApi) return _mock.deleteCatalogExtra(extraId);
    if (AppConfig.useFirestoreBackend) {
      try {
        await _firestore.deleteCatalogExtra(extraId);
        return;
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
      }
    }
    await _mock.deleteCatalogExtra(extraId);
  }

  Future<List<Product>> getProducts({String? branchId}) async {
    if (AppConfig.useMockApi) {
      return _resolveProducts(await _mock.getProducts(branchId: branchId));
    }
    if (AppConfig.useFirestoreBackend) {
      try {
        if (AppConfig.useFirestore) await _firestore.ensureSeeded();
        final products = await _firestore.getProducts(branchId: branchId);
        // Windows ops: boş veya hata durumunda mock katalog göstermeyelim —
        // admin'in eklediği ürünler kaybolmuş gibi görünür.
        if (products.isEmpty && !AppConfig.useWindowsOpsFirestoreRest) {
          return _resolveProducts(await _mock.getProducts(branchId: branchId));
        }
        final migrated = await _migrateLocalProductImages(products);
        return _resolveProducts(migrated);
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
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
    } else if (AppConfig.useFirestoreBackend) {
      try {
        updated =
            await _firestore.updateProductAvailability(productId, available);
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
        updated = await _mock.updateProductAvailability(productId, available);
      }
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
    } else if (AppConfig.useFirestoreBackend) {
      try {
        created = await _firestore
            .createProduct(product)
            .timeout(AppConfig.apiTimeout);
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
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
    } else if (AppConfig.useFirestoreBackend) {
      try {
        updated = await _firestore
            .updateProduct(product)
            .timeout(AppConfig.apiTimeout);
        await _clearWaiterCatalogPriceOverride(product.id, isExtra: false);
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
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
    if (AppConfig.useFirestoreBackend) {
      try {
        return _firestore.deleteProduct(productId);
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
      }
    }
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

  Future<List<Order>> getCustomerOrders(AuthState auth) async {
    final keys = customerIdentityKeys(auth);
    final ten = normalizeTrPhoneDigits(auth.phone);
    if (AppConfig.useMockApi) {
      final orders = await _mock.getOrders();
      return orders
          .where((order) => orderBelongsToCustomer(order, auth))
          .toList();
    }
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.getCustomerOrders(
          customerIds: keys,
          phoneDigits: ten,
        );
      } catch (_) {
        final orders = await _mock.getOrders();
        return orders
            .where((order) => orderBelongsToCustomer(order, auth))
            .toList();
      }
    }
    try {
      final models = await _remote.getOrders();
      return models
          .map(EntityMappers.toOrder)
          .where((order) => orderBelongsToCustomer(order, auth))
          .toList();
    } catch (_) {
      final orders = await _mock.getOrders();
      return orders
          .where((order) => orderBelongsToCustomer(order, auth))
          .toList();
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
    int? tableNumber,
    required String waiterId,
    required String waiterName,
    String? waiterCode,
    String? orderNote,
    List<String> preparationTags = const [],
    PaymentMethod paymentMethod = PaymentMethod.cashOnDelivery,
    bool isPickup = false,
    bool isTableAddon = false,
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
        paymentMethod: paymentMethod,
        isPickup: isPickup,
        isTableAddon: isTableAddon,
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
      paymentMethod: paymentMethod,
      isPickup: isPickup,
      isTableAddon: isTableAddon,
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

  Future<List<Order>> moveDineInTableOrders({
    required String branchId,
    required int fromTableNumber,
    required int toTableNumber,
  }) async {
    if (AppConfig.useMockApi) {
      return _mock.moveDineInTableOrders(
        branchId: branchId,
        fromTableNumber: fromTableNumber,
        toTableNumber: toTableNumber,
      );
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.moveDineInTableOrders(
        branchId: branchId,
        fromTableNumber: fromTableNumber,
        toTableNumber: toTableNumber,
      );
    }
    return _mock.moveDineInTableOrders(
      branchId: branchId,
      fromTableNumber: fromTableNumber,
      toTableNumber: toTableNumber,
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
    if (AppConfig.useFirestoreBackend) return _firestore.sendOtp(phone, role);
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

  Future<AuthUserModel> verifyOtp(
    String phone,
    String otp,
    String role, {
    String? name,
    String? password,
  }) async {
    if (AppConfig.useMockApi) {
      return _mock.verifyOtp(phone, otp, role, name: name, password: password);
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.verifyOtp(
        phone,
        otp,
        role,
        name: name,
        password: password,
      );
    }
    try {
      return await _remote.verifyOtp(phone, otp, role);
    } catch (_) {
      return _mock.verifyOtp(phone, otp, role, name: name, password: password);
    }
  }

  Future<AuthUserModel> loginCustomerPhonePassword(
    String phone,
    String password,
  ) async {
    if (AppConfig.useMockApi) {
      return _mock.loginCustomerPhonePassword(phone, password);
    }
    if (AppConfig.useFirestoreBackend) {
      return _firestore.loginCustomerPhonePassword(phone, password);
    }
    try {
      return await _firestore.loginCustomerPhonePassword(phone, password);
    } on AuthCredentialsException {
      rethrow;
    } catch (_) {
      return _mock.loginCustomerPhonePassword(phone, password);
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
    if (AppConfig.useFirestoreBackend) {
      return _firestore.loginWithEmailPassword(email, password, role);
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

  Future<List<DeliveryAddress>> getUserAddresses(String userId) async {
    if (AppConfig.useMockApi || !AppConfig.useFirestore) return const [];
    return _firestore.getUserAddresses(userId);
  }

  Future<void> saveUserAddresses(
    String userId,
    List<DeliveryAddress> addresses,
  ) async {
    if (AppConfig.useMockApi || !AppConfig.useFirestore) return;
    await _firestore.saveUserAddresses(userId, addresses);
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
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.getBranches();
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
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
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.getAdminUsers();
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
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
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.getAdminReports();
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
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
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.createBranch(branch);
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
        return _mock.createBranch(branch);
      }
    }
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
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.updateBranch(branch);
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
        return _mock.updateBranch(branch);
      }
    }
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
    if (AppConfig.useFirestoreBackend) {
      try {
        await _firestore.deleteBranch(branchId);
        return;
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
      }
    }
    try {
      await _remote.deleteBranch(branchId);
    } catch (_) {
      await _mock.deleteBranch(branchId);
    }
  }

  Future<AdminUserModel> createUser(AdminUserModel user) async {
    if (AppConfig.useMockApi) return _mock.createAdminUser(user);
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.createAdminUser(user);
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
        return _mock.createAdminUser(user);
      }
    }
    try {
      return await _remote.createUser(user);
    } catch (_) {
      return _mock.createAdminUser(user);
    }
  }

  Future<AdminUserModel> updateUser(AdminUserModel user) async {
    if (AppConfig.useMockApi) return _mock.updateAdminUser(user);
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.updateAdminUser(user);
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
        return _mock.updateAdminUser(user);
      }
    }
    try {
      return await _remote.updateUser(user);
    } catch (_) {
      return _mock.updateAdminUser(user);
    }
  }

  Future<void> deleteUser(String userId) async {
    if (AppConfig.useMockApi) return _mock.deleteAdminUser(userId);
    if (AppConfig.useFirestoreBackend) {
      try {
        await _firestore.deleteAdminUser(userId);
        return;
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
      }
    }
    try {
      await _remote.deleteUser(userId);
    } catch (_) {
      await _mock.deleteAdminUser(userId);
    }
  }

  Future<WaiterModeSettings> getWaiterModeSettings() async {
    if (AppConfig.useMockApi) return _mock.getWaiterModeSettings();
    if (AppConfig.useFirestoreBackend) {
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
    if (AppConfig.useFirestoreBackend) {
      return _firestore.updateWaiterModeSettings(settings);
    }
    return _mock.updateWaiterModeSettings(settings);
  }

  Future<QrMenuSettings> getQrMenuSettings() async {
    if (AppConfig.useMockApi) return QrMenuSettings.defaults;
    if (AppConfig.useFirestoreBackend) {
      try {
        return await _firestore.getQrMenuSettings();
      } catch (_) {
        if (AppConfig.useWindowsOpsFirestoreRest) rethrow;
        return QrMenuSettings.defaults;
      }
    }
    return QrMenuSettings.defaults;
  }

  Future<QrMenuSettings> updateQrMenuSettings(QrMenuSettings settings) async {
    if (AppConfig.useMockApi) return settings;
    if (AppConfig.useFirestoreBackend) {
      return _firestore.updateQrMenuSettings(settings);
    }
    return settings;
  }

  Stream<List<TableServiceRequest>> watchPendingTableServiceRequests({
    String? branchId,
  }) {
    if (AppConfig.useMockApi) {
      return Stream.value(const []);
    }
    if (AppConfig.useFirestoreBackend) {
      try {
        return _firestore.watchPendingTableServiceRequests(branchId: branchId);
      } catch (_) {
        return Stream.value(const []);
      }
    }
    return Stream.value(const []);
  }

  Future<void> acknowledgeTableServiceRequest(String requestId) async {
    if (AppConfig.useMockApi) return;
    if (AppConfig.useFirestoreBackend) {
      await _firestore.acknowledgeTableServiceRequest(requestId);
    }
  }

  Stream<WaiterModeSettings> watchWaiterModeSettings() {
    if (AppConfig.useMockApi) {
      return _mock.watchWaiterModeSettings();
    }
    if (AppConfig.useFirestoreBackend) {
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
