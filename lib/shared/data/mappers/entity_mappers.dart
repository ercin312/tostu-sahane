import '../../domain/entities/branch.dart';
import '../../domain/entities/geo_point.dart';
import '../../domain/entities/order.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_extra.dart';
import '../../domain/entities/product_combo_item.dart';
import '../../domain/entities/user.dart';
import '../models/api_models.dart';

abstract final class EntityMappers {
  static Branch toBranch(BranchModel model) => Branch(
        id: model.id,
        name: model.name,
        address: model.address,
        latitude: model.latitude,
        longitude: model.longitude,
        distanceKm: model.distanceKm,
        deliveryZoneMode: DeliveryZoneMode.values.byName(model.deliveryZoneMode),
        deliveryRadiusKm: model.deliveryRadiusKm,
        deliveryPolygon: model.deliveryPolygon.map(toGeoPoint).toList(),
        openTime: model.openTime,
        closeTime: model.closeTime,
        baseDeliveryFee: model.baseDeliveryFee,
        freeDeliveryMinOrder: model.freeDeliveryMinOrder,
        deliveryFeePerKm: model.deliveryFeePerKm,
        prepTimeMinutes: model.prepTimeMinutes,
      );

  static GeoPoint toGeoPoint(GeoPointModel model) => GeoPoint(
        latitude: model.latitude,
        longitude: model.longitude,
      );

  static Product toProduct(ProductModel model) => Product(
        id: model.id,
        nameKey: model.nameKey,
        descriptionKey: model.descriptionKey,
        price: model.price,
        category: ProductCategory.values.byName(model.category),
        isAvailable: model.isAvailable,
        imageColorValue: model.imageColorValue,
        imageUrl: model.imageUrl,
        extras: model.extras.map(toProductExtra).toList(),
        extraIds: model.extraIds,
        isCombo: model.isCombo,
        comboItems: model.comboItems.map(toProductComboItem).toList(),
        isRecommended: model.isRecommended,
      );

  static ProductComboItem toProductComboItem(ProductComboItemModel model) =>
      ProductComboItem(
        productId: model.productId,
        nameKey: model.nameKey,
        quantity: model.quantity,
      );

  static ProductExtra toProductExtra(ProductExtraModel model) => ProductExtra(
        id: model.id,
        name: model.name,
        price: model.price,
        imageUrl: model.imageUrl,
      );

  static Order toOrder(OrderModel model) {
    final stamps = <OrderStatus, DateTime>{};
    model.statusTimestamps.forEach((key, value) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        stamps[OrderStatus.values.byName(key)] = parsed;
      }
    });
    final actorIds = <OrderStatus, String>{};
    model.statusActorIds.forEach((key, value) {
      actorIds[OrderStatus.values.byName(key)] = value;
    });
    final actorNames = <OrderStatus, String>{};
    model.statusActorNames.forEach((key, value) {
      actorNames[OrderStatus.values.byName(key)] = value;
    });
    return Order(
        id: model.id,
        orderNumber: model.orderNumber,
        customerId: model.customerId,
        customerName: model.customerName,
        branchId: model.branchId,
        items: model.items.map(toCartItem).toList(),
        totalAmount: model.totalAmount,
        status: OrderStatus.values.byName(model.status),
        createdAt: DateTime.parse(model.createdAt),
        address: model.address,
        paymentMethod: PaymentMethod.values.byName(model.paymentMethod),
        courierId: model.courierId,
        courierName: model.courierName,
        orderNote: model.orderNote,
        preparationTags: List<String>.from(model.preparationTags),
        deliveryNow: model.deliveryNow,
        scheduledAt: model.scheduledAt != null
            ? DateTime.tryParse(model.scheduledAt!)
            : null,
        deliveryLatitude: model.deliveryLatitude,
        deliveryLongitude: model.deliveryLongitude,
        customerPhone: model.customerPhone,
        deliveryDirections: model.deliveryDirections,
        paymentTransactionId: model.paymentTransactionId,
        statusTimestamps: stamps,
        courierLatitude: model.courierLatitude,
        courierLongitude: model.courierLongitude,
        rating: model.rating,
        ratingComment: model.ratingComment,
        couponCode: model.couponCode,
        discountAmount: model.discountAmount,
        deliveryFeeAmount: model.deliveryFeeAmount,
        estimatedDeliveryMinutes: model.estimatedDeliveryMinutes,
        statusActorIds: actorIds,
        statusActorNames: actorNames,
        approachNotificationSent: model.approachNotificationSent,
        orderType: OrderType.values.byName(model.orderType),
        tableNumber: model.tableNumber,
        waiterId: model.waiterId,
        waiterName: model.waiterName,
        waiterCode: model.waiterCode,
      );
  }

  static CartItem toCartItem(CartItemModel model) => CartItem(
        id: model.id,
        productId: model.productId,
        productNameKey: model.productNameKey,
        unitPrice: model.unitPrice,
        quantity: model.quantity,
        selectedOptions: model.selectedOptions,
        portionKey: model.portionKey,
        note: model.note,
      );

  static OrderModel fromOrder(Order order) {
    final stamps = <String, String>{};
    order.statusTimestamps.forEach((key, value) {
      stamps[key.name] = value.toIso8601String();
    });
    final actorIds = <String, String>{};
    order.statusActorIds.forEach((key, value) {
      actorIds[key.name] = value;
    });
    final actorNames = <String, String>{};
    order.statusActorNames.forEach((key, value) {
      actorNames[key.name] = value;
    });
    return OrderModel(
        id: order.id,
        orderNumber: order.orderNumber,
        customerId: order.customerId,
        customerName: order.customerName,
        branchId: order.branchId,
        items: order.items.map(fromCartItem).toList(),
        totalAmount: order.totalAmount,
        status: order.status.name,
        createdAt: order.createdAt.toIso8601String(),
        address: order.address,
        paymentMethod: order.paymentMethod.name,
        courierId: order.courierId,
        courierName: order.courierName,
        orderNote: order.orderNote,
        preparationTags: List<String>.from(order.preparationTags),
        deliveryNow: order.deliveryNow,
        scheduledAt: order.scheduledAt?.toIso8601String(),
        deliveryLatitude: order.deliveryLatitude,
        deliveryLongitude: order.deliveryLongitude,
        customerPhone: order.customerPhone,
        deliveryDirections: order.deliveryDirections,
        paymentTransactionId: order.paymentTransactionId,
        statusTimestamps: stamps,
        courierLatitude: order.courierLatitude,
        courierLongitude: order.courierLongitude,
        rating: order.rating,
        ratingComment: order.ratingComment,
        couponCode: order.couponCode,
        discountAmount: order.discountAmount,
        deliveryFeeAmount: order.deliveryFeeAmount,
        estimatedDeliveryMinutes: order.estimatedDeliveryMinutes,
        statusActorIds: actorIds,
        statusActorNames: actorNames,
        approachNotificationSent: order.approachNotificationSent,
        orderType: order.orderType.name,
        tableNumber: order.tableNumber,
        waiterId: order.waiterId,
        waiterName: order.waiterName,
        waiterCode: order.waiterCode,
      );
  }

  static CartItemModel fromCartItem(CartItem item) => CartItemModel(
        id: item.id,
        productId: item.productId,
        productNameKey: item.productNameKey,
        unitPrice: item.unitPrice,
        quantity: item.quantity,
        selectedOptions: item.selectedOptions,
        portionKey: item.portionKey,
        note: item.note,
      );

  static BranchModel fromBranch(Branch branch) => BranchModel(
        id: branch.id,
        name: branch.name,
        address: branch.address,
        latitude: branch.latitude,
        longitude: branch.longitude,
        distanceKm: branch.distanceKm,
        deliveryZoneMode: branch.deliveryZoneMode.name,
        deliveryRadiusKm: branch.deliveryRadiusKm,
        deliveryPolygon: branch.deliveryPolygon.map(fromGeoPoint).toList(),
        openTime: branch.openTime,
        closeTime: branch.closeTime,
        baseDeliveryFee: branch.baseDeliveryFee,
        freeDeliveryMinOrder: branch.freeDeliveryMinOrder,
        deliveryFeePerKm: branch.deliveryFeePerKm,
        prepTimeMinutes: branch.prepTimeMinutes,
      );

  static GeoPointModel fromGeoPoint(GeoPoint point) => GeoPointModel(
        latitude: point.latitude,
        longitude: point.longitude,
      );

  static ProductModel fromProduct(Product product) => ProductModel(
        id: product.id,
        nameKey: product.nameKey,
        descriptionKey: product.descriptionKey,
        price: product.price,
        category: product.category.name,
        isAvailable: product.isAvailable,
        imageColorValue: product.imageColorValue,
        imageUrl: product.imageUrl,
        extras: const [],
        extraIds: product.extraIds.isNotEmpty
            ? product.extraIds
            : product.extras.map((extra) => extra.id).toList(),
        isCombo: product.isCombo,
        comboItems: product.comboItems.map(fromProductComboItem).toList(),
        isRecommended: product.isRecommended,
      );

  static ProductComboItemModel fromProductComboItem(ProductComboItem item) =>
      ProductComboItemModel(
        productId: item.productId,
        nameKey: item.nameKey,
        quantity: item.quantity,
      );

  static ProductExtraModel fromProductExtra(ProductExtra extra) =>
      ProductExtraModel(
        id: extra.id,
        name: extra.name,
        price: extra.price,
        imageUrl: extra.imageUrl,
      );

  static User toUser(AuthUserModel model) => User(
        id: model.id,
        name: model.name,
        role: UserRole.values.byName(model.role),
        branchId: model.branchId,
      );
}
