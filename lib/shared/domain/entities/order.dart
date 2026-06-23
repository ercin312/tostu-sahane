import 'package:equatable/equatable.dart';

enum OrderStatus {
  received,
  preparing,
  waitingCourier,
  onTheWay,
  delivered,
  cancelled,
}

enum OrderType { delivery, dineIn }

enum PaymentMethod { onlineCard, cashOnDelivery, cardOnDelivery }

class PaymentResult {
  const PaymentResult({
    required this.transactionId,
    required this.amount,
  });

  final String transactionId;
  final double amount;
}

class PaymentException implements Exception {
  const PaymentException(this.messageKey);
  final String messageKey;
}

class CartItem extends Equatable {
  const CartItem({
    required this.id,
    required this.productId,
    required this.productNameKey,
    required this.unitPrice,
    required this.quantity,
    this.selectedOptions = const [],
    this.portionKey,
    this.note,
  });

  final String id;
  final String productId;
  final String productNameKey;
  final double unitPrice;
  final int quantity;
  final List<String> selectedOptions;
  final String? portionKey;
  final String? note;

  double get totalPrice => unitPrice * quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      productId: productId,
      productNameKey: productNameKey,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
      selectedOptions: selectedOptions,
      portionKey: portionKey,
      note: note,
    );
  }

  @override
  List<Object?> get props =>
      [id, productId, productNameKey, unitPrice, quantity, selectedOptions];
}

class Order extends Equatable {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.branchId,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.address,
    required this.paymentMethod,
    this.courierId,
    this.courierName,
    this.orderNote,
    this.preparationTags = const [],
    this.deliveryNow = true,
    this.scheduledAt,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.customerPhone,
    this.deliveryDirections,
    this.paymentTransactionId,
    this.statusTimestamps = const {},
    this.courierLatitude,
    this.courierLongitude,
    this.rating,
    this.ratingComment,
    this.couponCode,
    this.discountAmount = 0,
    this.deliveryFeeAmount = 0,
    this.estimatedDeliveryMinutes,
    this.statusActorIds = const {},
    this.statusActorNames = const {},
    this.approachNotificationSent = false,
    this.orderType = OrderType.delivery,
    this.tableNumber,
    this.waiterId,
    this.waiterName,
    this.waiterCode,
  });

  final String id;
  final int orderNumber;
  final String customerId;
  final String customerName;
  final String branchId;
  final List<CartItem> items;
  final double totalAmount;
  final OrderStatus status;
  final DateTime createdAt;
  final String address;
  final PaymentMethod paymentMethod;
  final String? courierId;
  final String? courierName;
  final String? orderNote;
  final List<String> preparationTags;
  final bool deliveryNow;
  final DateTime? scheduledAt;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? customerPhone;
  final String? deliveryDirections;
  final String? paymentTransactionId;
  final Map<OrderStatus, DateTime> statusTimestamps;
  final double? courierLatitude;
  final double? courierLongitude;
  final int? rating;
  final String? ratingComment;
  final String? couponCode;
  final double discountAmount;
  final double deliveryFeeAmount;
  final int? estimatedDeliveryMinutes;
  final Map<OrderStatus, String> statusActorIds;
  final Map<OrderStatus, String> statusActorNames;
  final bool approachNotificationSent;
  final OrderType orderType;
  final int? tableNumber;
  final String? waiterId;
  final String? waiterName;
  final String? waiterCode;

  bool get isDineIn => orderType == OrderType.dineIn;

  bool get isDelivery => orderType == OrderType.delivery;

  bool get isActive =>
      status != OrderStatus.delivered && status != OrderStatus.cancelled;

  bool get canCustomerCancel =>
      status == OrderStatus.received || status == OrderStatus.preparing;

  bool get canBranchReject =>
      status == OrderStatus.received || status == OrderStatus.preparing;

  DateTime? atStatus(OrderStatus value) => statusTimestamps[value];

  /// Toplam sipariş süresi (dakika): oluşturulma → teslim.
  int? get totalFulfillmentMinutes {
    final end = atStatus(OrderStatus.delivered);
    if (end == null) return null;
    return end.difference(createdAt).inMinutes;
  }

  String? actorNameFor(OrderStatus status) => statusActorNames[status];

  /// Teslimat süresi (dakika): yola çıkış → teslim.
  int? get deliveryDurationMinutes {
    final start = atStatus(OrderStatus.onTheWay);
    final end = atStatus(OrderStatus.delivered);
    if (start == null || end == null) return null;
    return end.difference(start).inMinutes;
  }

  Order copyWith({
    OrderStatus? status,
    String? courierId,
    String? courierName,
    double? deliveryLatitude,
    double? deliveryLongitude,
    String? customerPhone,
    String? deliveryDirections,
    String? paymentTransactionId,
    PaymentMethod? paymentMethod,
    Map<OrderStatus, DateTime>? statusTimestamps,
    double? courierLatitude,
    double? courierLongitude,
    int? rating,
    String? ratingComment,
    String? couponCode,
    double? discountAmount,
    double? deliveryFeeAmount,
    int? estimatedDeliveryMinutes,
    Map<OrderStatus, String>? statusActorIds,
    Map<OrderStatus, String>? statusActorNames,
    bool? approachNotificationSent,
    OrderType? orderType,
    int? tableNumber,
    String? waiterId,
    String? waiterName,
    String? waiterCode,
    List<String>? preparationTags,
    List<CartItem>? items,
    double? totalAmount,
    String? orderNote,
  }) {
    return Order(
      id: id,
      orderNumber: orderNumber,
      customerId: customerId,
      customerName: customerName,
      branchId: branchId,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      createdAt: createdAt,
      address: address,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      courierId: courierId ?? this.courierId,
      courierName: courierName ?? this.courierName,
      orderNote: orderNote ?? this.orderNote,
      preparationTags: preparationTags ?? this.preparationTags,
      deliveryNow: deliveryNow,
      scheduledAt: scheduledAt,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      customerPhone: customerPhone ?? this.customerPhone,
      deliveryDirections: deliveryDirections ?? this.deliveryDirections,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      statusTimestamps: statusTimestamps ?? this.statusTimestamps,
      courierLatitude: courierLatitude ?? this.courierLatitude,
      courierLongitude: courierLongitude ?? this.courierLongitude,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      couponCode: couponCode ?? this.couponCode,
      discountAmount: discountAmount ?? this.discountAmount,
      deliveryFeeAmount: deliveryFeeAmount ?? this.deliveryFeeAmount,
      estimatedDeliveryMinutes:
          estimatedDeliveryMinutes ?? this.estimatedDeliveryMinutes,
      statusActorIds: statusActorIds ?? this.statusActorIds,
      statusActorNames: statusActorNames ?? this.statusActorNames,
      approachNotificationSent:
          approachNotificationSent ?? this.approachNotificationSent,
      orderType: orderType ?? this.orderType,
      tableNumber: tableNumber ?? this.tableNumber,
      waiterId: waiterId ?? this.waiterId,
      waiterName: waiterName ?? this.waiterName,
      waiterCode: waiterCode ?? this.waiterCode,
    );
  }

  Order withStatus(
    OrderStatus newStatus, {
    DateTime? at,
    String? actorId,
    String? actorName,
  }) {
    final stamps = Map<OrderStatus, DateTime>.from(statusTimestamps);
    stamps[newStatus] = at ?? DateTime.now();
    final ids = Map<OrderStatus, String>.from(statusActorIds);
    final names = Map<OrderStatus, String>.from(statusActorNames);
    if (actorId != null) ids[newStatus] = actorId;
    if (actorName != null) names[newStatus] = actorName;
    return copyWith(
      status: newStatus,
      statusTimestamps: stamps,
      statusActorIds: ids,
      statusActorNames: names,
    );
  }

  @override
  List<Object?> get props =>
      [id, orderNumber, status, totalAmount, courierLatitude, courierLongitude];
}
