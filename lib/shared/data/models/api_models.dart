class BranchModel {
  const BranchModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.distanceKm = 0,
    this.deliveryZoneMode = 'radius',
    this.deliveryRadiusKm = 3.0,
    this.deliveryPolygon = const [],
    this.openTime = '09:00',
    this.closeTime = '23:00',
    this.baseDeliveryFee = 15.0,
    this.freeDeliveryMinOrder = 150.0,
    this.deliveryFeePerKm = 5.0,
    this.prepTimeMinutes = 15,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) => BranchModel(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
        deliveryZoneMode: json['delivery_zone_mode'] as String? ?? 'radius',
        deliveryRadiusKm:
            (json['delivery_radius_km'] as num?)?.toDouble() ?? 3.0,
        deliveryPolygon: (json['delivery_polygon'] as List<dynamic>?)
                ?.map(
                  (e) => GeoPointModel.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            [],
        openTime: json['open_time'] as String? ?? '09:00',
        closeTime: json['close_time'] as String? ?? '23:00',
        baseDeliveryFee:
            (json['base_delivery_fee'] as num?)?.toDouble() ?? 15.0,
        freeDeliveryMinOrder:
            (json['free_delivery_min_order'] as num?)?.toDouble() ?? 150.0,
        deliveryFeePerKm:
            (json['delivery_fee_per_km'] as num?)?.toDouble() ?? 5.0,
        prepTimeMinutes: json['prep_time_minutes'] as int? ?? 15,
      );

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String deliveryZoneMode;
  final double deliveryRadiusKm;
  final List<GeoPointModel> deliveryPolygon;
  final String openTime;
  final String closeTime;
  final double baseDeliveryFee;
  final double freeDeliveryMinOrder;
  final double deliveryFeePerKm;
  final int prepTimeMinutes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'distance_km': distanceKm,
        'delivery_zone_mode': deliveryZoneMode,
        'delivery_radius_km': deliveryRadiusKm,
        'delivery_polygon':
            deliveryPolygon.map((e) => e.toJson()).toList(),
        'open_time': openTime,
        'close_time': closeTime,
        'base_delivery_fee': baseDeliveryFee,
        'free_delivery_min_order': freeDeliveryMinOrder,
        'delivery_fee_per_km': deliveryFeePerKm,
        'prep_time_minutes': prepTimeMinutes,
      };
}

class GeoPointModel {
  const GeoPointModel({
    required this.latitude,
    required this.longitude,
  });

  factory GeoPointModel.fromJson(Map<String, dynamic> json) => GeoPointModel(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.price,
    required this.category,
    required this.isAvailable,
    required this.imageColorValue,
    this.imageUrl,
    this.extras = const [],
    this.extraIds = const [],
    this.isCombo = false,
    this.comboItems = const [],
    this.isRecommended = false,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as String,
        nameKey: json['name_key'] as String,
        descriptionKey: json['description_key'] as String,
        price: (json['price'] as num).toDouble(),
        category: json['category'] as String,
        isAvailable: json['is_available'] as bool? ?? true,
        imageColorValue: json['image_color_value'] as int? ?? 0xFFFFE0E6,
        imageUrl: json['image_url'] as String?,
        extras: (json['extras'] as List<dynamic>?)
                ?.map((e) => ProductExtraModel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        extraIds: (json['extra_ids'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        isCombo: json['is_combo'] as bool? ?? false,
        comboItems: (json['combo_items'] as List<dynamic>?)
                ?.map(
                  (e) => ProductComboItemModel.fromJson(
                    e as Map<String, dynamic>,
                  ),
                )
                .toList() ??
            [],
        isRecommended: json['is_recommended'] as bool? ?? false,
      );

  final String id;
  final String nameKey;
  final String descriptionKey;
  final double price;
  final String category;
  final bool isAvailable;
  final int imageColorValue;
  final String? imageUrl;
  final List<ProductExtraModel> extras;
  final List<String> extraIds;
  final bool isCombo;
  final List<ProductComboItemModel> comboItems;
  final bool isRecommended;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_key': nameKey,
        'description_key': descriptionKey,
        'price': price,
        'category': category,
        'is_available': isAvailable,
        'image_color_value': imageColorValue,
        'image_url': imageUrl,
        'extras': extras.map((e) => e.toJson()).toList(),
        'extra_ids': extraIds,
        'is_combo': isCombo,
        'combo_items': comboItems.map((e) => e.toJson()).toList(),
        'is_recommended': isRecommended,
      };
}

class ProductComboItemModel {
  const ProductComboItemModel({
    required this.productId,
    required this.nameKey,
    this.quantity = 1,
  });

  factory ProductComboItemModel.fromJson(Map<String, dynamic> json) =>
      ProductComboItemModel(
        productId: json['product_id'] as String,
        nameKey: json['name_key'] as String,
        quantity: json['quantity'] as int? ?? 1,
      );

  final String productId;
  final String nameKey;
  final int quantity;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name_key': nameKey,
        'quantity': quantity,
      };
}

class ProductExtraModel {
  const ProductExtraModel({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
  });

  factory ProductExtraModel.fromJson(Map<String, dynamic> json) =>
      ProductExtraModel(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        imageUrl: json['image_url'] as String?,
      );

  final String id;
  final String name;
  final double price;
  final String? imageUrl;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'image_url': imageUrl,
      };
}

class CartItemModel {
  const CartItemModel({
    required this.id,
    required this.productId,
    required this.productNameKey,
    required this.unitPrice,
    required this.quantity,
    this.selectedOptions = const [],
    this.portionKey,
    this.note,
  });

  factory CartItemModel.fromJson(Map<String, dynamic> json) => CartItemModel(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        productNameKey: json['product_name_key'] as String,
        unitPrice: (json['unit_price'] as num).toDouble(),
        quantity: json['quantity'] as int,
        selectedOptions: (json['selected_options'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        portionKey: json['portion_key'] as String?,
        note: json['note'] as String?,
      );

  final String id;
  final String productId;
  final String productNameKey;
  final double unitPrice;
  final int quantity;
  final List<String> selectedOptions;
  final String? portionKey;
  final String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'product_id': productId,
        'product_name_key': productNameKey,
        'unit_price': unitPrice,
        'quantity': quantity,
        'selected_options': selectedOptions,
        'portion_key': portionKey,
        'note': note,
      };
}

class OrderModel {
  const OrderModel({
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
    this.orderType = 'delivery',
    this.tableNumber,
    this.waiterId,
    this.waiterName,
    this.waiterCode,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final rawStamps = json['status_timestamps'] as Map<String, dynamic>?;
    final stamps = <String, String>{};
    rawStamps?.forEach((k, v) => stamps[k] = v as String);

    final rawActorIds = json['status_actor_ids'] as Map<String, dynamic>?;
    final actorIds = <String, String>{};
    rawActorIds?.forEach((k, v) => actorIds[k] = v as String);
    final rawActorNames = json['status_actor_names'] as Map<String, dynamic>?;
    final actorNames = <String, String>{};
    rawActorNames?.forEach((k, v) => actorNames[k] = v as String);

    return OrderModel(
        id: json['id'] as String,
        orderNumber: json['order_number'] as int,
        customerId: json['customer_id'] as String,
        customerName: json['customer_name'] as String,
        branchId: json['branch_id'] as String,
        items: (json['items'] as List<dynamic>)
            .map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalAmount: (json['total_amount'] as num).toDouble(),
        status: json['status'] as String,
        createdAt: json['created_at'] as String,
        address: json['address'] as String,
        paymentMethod: json['payment_method'] as String,
        courierId: json['courier_id'] as String?,
        courierName: json['courier_name'] as String?,
        orderNote: json['order_note'] as String?,
        preparationTags: (json['preparation_tags'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        deliveryNow: json['delivery_now'] as bool? ?? true,
        scheduledAt: json['scheduled_at'] as String?,
        deliveryLatitude: (json['delivery_latitude'] as num?)?.toDouble(),
        deliveryLongitude: (json['delivery_longitude'] as num?)?.toDouble(),
        customerPhone: json['customer_phone'] as String?,
        deliveryDirections: json['delivery_directions'] as String?,
        paymentTransactionId: json['payment_transaction_id'] as String?,
        statusTimestamps: stamps,
        courierLatitude: (json['courier_latitude'] as num?)?.toDouble(),
        courierLongitude: (json['courier_longitude'] as num?)?.toDouble(),
        rating: json['rating'] as int?,
        ratingComment: json['rating_comment'] as String?,
        couponCode: json['coupon_code'] as String?,
        discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
        deliveryFeeAmount:
            (json['delivery_fee_amount'] as num?)?.toDouble() ?? 0,
        estimatedDeliveryMinutes: json['estimated_delivery_minutes'] as int?,
        statusActorIds: actorIds,
        statusActorNames: actorNames,
        approachNotificationSent:
            json['approach_notification_sent'] as bool? ?? false,
        orderType: json['order_type'] as String? ?? 'delivery',
        tableNumber: (json['table_number'] as num?)?.toInt(),
        waiterId: json['waiter_id'] as String?,
        waiterName: json['waiter_name'] as String?,
        waiterCode: json['waiter_code'] as String?,
      );
  }

  final String id;
  final int orderNumber;
  final String customerId;
  final String customerName;
  final String branchId;
  final List<CartItemModel> items;
  final double totalAmount;
  final String status;
  final String createdAt;
  final String address;
  final String paymentMethod;
  final String? courierId;
  final String? courierName;
  final String? orderNote;
  final List<String> preparationTags;
  final bool deliveryNow;
  final String? scheduledAt;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final String? customerPhone;
  final String? deliveryDirections;
  final String? paymentTransactionId;
  final Map<String, String> statusTimestamps;
  final double? courierLatitude;
  final double? courierLongitude;
  final int? rating;
  final String? ratingComment;
  final String? couponCode;
  final double discountAmount;
  final double deliveryFeeAmount;
  final int? estimatedDeliveryMinutes;
  final Map<String, String> statusActorIds;
  final Map<String, String> statusActorNames;
  final bool approachNotificationSent;
  final String orderType;
  final int? tableNumber;
  final String? waiterId;
  final String? waiterName;
  final String? waiterCode;

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_number': orderNumber,
        'customer_id': customerId,
        'customer_name': customerName,
        'branch_id': branchId,
        'items': items.map((e) => e.toJson()).toList(),
        'total_amount': totalAmount,
        'status': status,
        'created_at': createdAt,
        'address': address,
        'payment_method': paymentMethod,
        'courier_id': courierId,
        'courier_name': courierName,
        'order_note': orderNote,
        'preparation_tags': preparationTags,
        'delivery_now': deliveryNow,
        'scheduled_at': scheduledAt,
        'delivery_latitude': deliveryLatitude,
        'delivery_longitude': deliveryLongitude,
        'customer_phone': customerPhone,
        'delivery_directions': deliveryDirections,
        'payment_transaction_id': paymentTransactionId,
        'status_timestamps': statusTimestamps,
        'courier_latitude': courierLatitude,
        'courier_longitude': courierLongitude,
        'rating': rating,
        'rating_comment': ratingComment,
        'coupon_code': couponCode,
        'discount_amount': discountAmount,
        'delivery_fee_amount': deliveryFeeAmount,
        'estimated_delivery_minutes': estimatedDeliveryMinutes,
        'status_actor_ids': statusActorIds,
        'status_actor_names': statusActorNames,
        'approach_notification_sent': approachNotificationSent,
        'order_type': orderType,
        'table_number': tableNumber,
        'waiter_id': waiterId,
        'waiter_name': waiterName,
        'waiter_code': waiterCode,
      };
}

class AuthUserModel {
  const AuthUserModel({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    this.accessToken,
    this.refreshToken,
    this.branchId,
    this.username,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) => AuthUserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        phone: json['phone'] as String,
        accessToken: json['access_token'] as String?,
        refreshToken: json['refresh_token'] as String?,
        branchId: json['branch_id'] as String?,
        username: json['username'] as String?,
      );

  final String id;
  final String name;
  final String role;
  final String phone;
  final String? accessToken;
  final String? refreshToken;
  final String? branchId;
  final String? username;
}

class AdminUserModel {
  const AdminUserModel({
    required this.id,
    required this.name,
    required this.role,
    required this.phone,
    required this.isActive,
    this.branchId,
    this.username,
    this.password,
  });

  factory AdminUserModel.fromJson(Map<String, dynamic> json) => AdminUserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        role: json['role'] as String,
        phone: json['phone'] as String,
        isActive: json['is_active'] as bool? ?? true,
        branchId: json['branch_id'] as String?,
        username: json['username'] as String?,
        password: json['password'] as String?,
      );

  final String id;
  final String name;
  final String role;
  final String phone;
  final bool isActive;
  final String? branchId;
  final String? username;
  final String? password;

  AdminUserModel copyWith({
    String? id,
    String? name,
    String? role,
    String? phone,
    bool? isActive,
    String? branchId,
    String? username,
    String? password,
  }) {
    return AdminUserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      branchId: branchId ?? this.branchId,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'phone': phone,
        'is_active': isActive,
        'branch_id': branchId,
        'username': username,
        'password': password,
      };
}

class AdminReportModel {
  const AdminReportModel({
    required this.totalRevenue,
    required this.totalOrders,
    required this.activeBranches,
  });

  factory AdminReportModel.fromJson(Map<String, dynamic> json) =>
      AdminReportModel(
        totalRevenue: (json['total_revenue'] as num).toDouble(),
        totalOrders: json['total_orders'] as int,
        activeBranches: json['active_branches'] as int,
      );

  final double totalRevenue;
  final int totalOrders;
  final int activeBranches;
}
