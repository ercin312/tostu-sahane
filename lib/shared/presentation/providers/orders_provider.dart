import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/analytics/ops_analytics.dart';
import '../../../core/config/app_settings_provider.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/orders/order_merge.dart';
import '../../../core/orders/order_workflow.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/customer_order_matching.dart';
import '../../../core/utils/delivery_eta_utils.dart';
import '../../../core/utils/localized_text.dart';
import '../../../core/utils/order_status_utils.dart';
import '../../../shared/domain/entities/user.dart';
import '../../../features/waiter/domain/table_session.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/customer/home/presentation/providers/branch_provider.dart';
import '../../data/datasources/local/local_datasources.dart';
import '../../domain/entities/order.dart';
import '../../domain/usecases/orders/place_order_use_case.dart';
import '../providers/repository_providers.dart';
import '../providers/use_case_providers.dart';

class OrdersNotifier extends AsyncNotifier<List<Order>> {
  final _local = OrderLocalDataSource();
  Timer? _pollTimer;
  Timer? _courierLocationTimer;
  StreamSubscription<List<Order>>? _ordersSub;

  @override
  Future<List<Order>> build() async {
    ref.onDispose(() {
      _pollTimer?.cancel();
      _courierLocationTimer?.cancel();
      _ordersSub?.cancel();
    });

    final cached = await _local.loadOrders();

    if (AppConfig.useMockApi) {
      await ref.read(mockApiDataSourceProvider).syncOrders(cached);
    }

    if (AppConfig.useFirestoreBackend) {
      _courierLocationTimer = Timer.periodic(
        const Duration(seconds: 12),
        (_) => _pushCourierLocation(),
      );
      _ordersSub = ref.read(orderRepositoryProvider).watchOrders().listen(
        (remote) async {
          final merged = _mergeOrders(state.value ?? cached, remote);
          state = AsyncData(merged);
          await _persist(merged);
        },
        onError: (_) {},
      );
      try {
        final remote = await ref.read(orderRepositoryProvider).getOrders();
        final merged = _mergeOrders(cached, remote);
        await _persist(merged);
        return merged;
      } catch (_) {
        return cached;
      }
    }

    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _syncFromRepository(),
    );
    _courierLocationTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) => _pushCourierLocation(),
    );

    try {
      final remote = await ref.read(orderRepositoryProvider).getOrders();
      final merged = _mergeOrders(cached, remote);
      await _persist(merged);
      return merged;
    } catch (_) {
      return cached;
    }
  }

  List<Order> _mergeOrders(List<Order> cached, List<Order> remote) {
    if (remote.isEmpty) return cached;
    final map = {for (final o in cached) o.id: o};
    for (final order in remote) {
      final existing = map[order.id];
      map[order.id] =
          existing == null ? order : OrderMerge.resolve(existing, order);
    }
    return map.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Order? _orderById(String orderId) {
    final orders = state.value ?? [];
    for (final order in orders) {
      if (order.id == orderId) return order;
    }
    return null;
  }

  String? _actorId() => ref.read(authProvider)?.user.id;

  String? _actorName() {
    final name = ref.read(authProvider)?.user.name;
    if (name == null) return null;
    return localizedOrRaw(name);
  }

  Future<void> _ensureMockHas(Order order) async {
    ref.read(mockApiDataSourceProvider).upsertOrder(order);
  }

  Future<void> _syncFromRepository() async {
    try {
      final remote = await ref.read(orderRepositoryProvider).getOrders();
      final current = state.value ?? [];
      final merged = _mergeOrders(current, remote);
      if (merged.length != current.length ||
          !_listsEqual(merged, current)) {
        state = AsyncData(merged);
        await _persist(merged);
      }
    } catch (_) {}
  }

  Future<void> _pushCourierLocation() async {
    final auth = ref.read(authProvider);
    if (auth?.user.role != UserRole.courier) return;

    final position = await LocationService.getCurrentPosition();
    if (position == null) return;

    final orders = state.value ?? [];
    for (final order in orders) {
      if (order.courierId == auth!.user.id &&
          order.status == OrderStatus.onTheWay) {
        await updateCourierLocation(
          order.id,
          position.latitude,
          position.longitude,
        );
      }
    }
  }

  bool _listsEqual(List<Order> a, List<Order> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final oa = a[i];
      final ob = b[i];
      if (oa.id != ob.id ||
          oa.status != ob.status ||
          oa.rating != ob.rating ||
          oa.courierLatitude != ob.courierLatitude ||
          oa.courierLongitude != ob.courierLongitude ||
          oa.statusTimestamps.length != ob.statusTimestamps.length) {
        return false;
      }
    }
    return true;
  }

  Future<void> _persist(List<Order> orders) async {
    await _local.saveOrders(orders);
  }

  Future<void> _updateState(List<Order> orders) async {
    state = AsyncData(orders);
    await _persist(orders);
  }

  Future<Order> placeOrder({
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
    final created = await ref.read(placeOrderUseCaseProvider).call(
          PlaceOrderParams(
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
          ),
        );
    final updated = [created, ...?state.value];
    await _ensureMockHas(created);
    await _updateState(updated);
    try {
      await NotificationService.instance.notifyNewOrder();
    } catch (_) {}
    return created;
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
    final created = await ref.read(orderRepositoryProvider).placeDineInOrder(
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
    final updated = [created, ...?state.value];
    await _ensureMockHas(created);
    await _updateState(updated);
    unawaited(refresh());
    return created;
  }

  Future<void> closeDineInTableBill({
    required int tableNumber,
    required PaymentMethod paymentMethod,
    String? paymentTransactionId,
  }) async {
    final branch = ref.read(managedBranchProvider).value;
    if (branch == null) {
      throw StateError('managed_branch_unavailable');
    }

    final openOnTable = (state.value ?? [])
        .where(
          (o) =>
              o.branchId == branch.id &&
              o.tableNumber == tableNumber &&
              isOpenDineInOrder(o),
        )
        .toList();

    final closed = await ref.read(orderRepositoryProvider).closeDineInTableBill(
          branchId: branch.id,
          tableNumber: tableNumber,
          paymentMethod: paymentMethod,
          paymentTransactionId: paymentTransactionId,
          actorId: _actorId(),
          actorName: _actorName(),
        );

    if (closed.isEmpty) {
      if (openOnTable.isNotEmpty) {
        throw StateError('dine_in_bill_close_failed');
      }
      return;
    }

    final current = List<Order>.from(state.value ?? []);
    for (final order in closed) {
      final index = current.indexWhere((o) => o.id == order.id);
      if (index >= 0) {
        current[index] = order;
      } else {
        current.insert(0, order);
      }
    }
    await _updateState(current);
    for (final order in closed) {
      await _ensureMockHas(order);
    }
    unawaited(refresh());
  }

  Future<void> voidDineInTableBill({required int tableNumber}) async {
    final branch = ref.read(managedBranchProvider).value;
    if (branch == null) {
      throw StateError('managed_branch_unavailable');
    }

    final openOnTable = (state.value ?? [])
        .where(
          (o) =>
              o.branchId == branch.id &&
              o.tableNumber == tableNumber &&
              isOpenDineInOrder(o),
        )
        .toList();

    final cancelled = await ref.read(orderRepositoryProvider).voidDineInTableBill(
          branchId: branch.id,
          tableNumber: tableNumber,
          actorId: _actorId(),
          actorName: _actorName(),
        );

    if (cancelled.isEmpty) {
      if (openOnTable.isNotEmpty) {
        throw StateError('dine_in_bill_void_failed');
      }
      return;
    }

    final current = List<Order>.from(state.value ?? []);
    for (final order in cancelled) {
      final index = current.indexWhere((o) => o.id == order.id);
      if (index >= 0) {
        current[index] = order;
      } else {
        current.insert(0, order);
      }
    }
    await _updateState(current);
    for (final order in cancelled) {
      await _ensureMockHas(order);
    }
    unawaited(refresh());
  }

  Future<Order> removeDineInOrderItem(
    String orderId,
    String cartItemId, {
    int quantity = 1,
  }) async {
    final existing = _orderById(orderId);
    if (existing == null) {
      throw StateError('Order not found: $orderId');
    }

    final repo = ref.read(orderRepositoryProvider);
    final updated = await repo.removeDineInOrderItem(
      orderId,
      cartItemId,
      quantity: quantity,
      actorId: _actorId(),
      actorName: _actorName(),
    );
    await _upsertOrder(updated);
    unawaited(refresh());
    return updated;
  }

  Future<Order> updateStatus(String orderId, OrderStatus status) async {
    final existing = _orderById(orderId);
    if (existing == null) {
      throw StateError('Order not found: $orderId');
    }
    if (existing.status != status &&
        !OrderStatusUtils.isValidTransition(existing.status, status)) {
      throw StateError(
        'Invalid status transition: ${existing.status.name} → ${status.name}',
      );
    }

    final optimistic = existing.withStatus(
      status,
      actorId: _actorId(),
      actorName: _actorName(),
    );
    await _upsertOrder(optimistic);

    final repo = ref.read(orderRepositoryProvider);
    try {
      final updated = await repo.updateStatus(
        orderId,
        status,
        actorId: _actorId(),
        actorName: _actorName(),
      );
      await _upsertOrder(updated);
      unawaited(NotificationService.instance.notifyOrderStatus(
        OrderStatusUtils.labelKey(status),
      ));
      return updated;
    } catch (_) {
      await _upsertOrder(existing);
      rethrow;
    }
  }

  Future<Order> performWorkflowAction(
    String orderId,
    OrderWorkflowAction action,
  ) async {
    final auth = ref.read(authProvider);
    final existing = _orderById(orderId);
    if (auth == null || existing == null) {
      throw StateError('Order or auth unavailable');
    }
    if (!OrderWorkflow.canPerform(auth.user, existing, action)) {
      throw StateError('Action not allowed: $action');
    }

    return switch (action) {
      OrderWorkflowAction.assignCourier => _assignCourierForUser(
          orderId,
          auth.user.id,
          _actorName() ?? auth.user.id,
        ),
      OrderWorkflowAction.reject => cancelOrder(orderId),
      _ => updateStatus(
          orderId,
          OrderWorkflow.targetStatus(existing, action)!,
        ),
    };
  }

  Future<Order> _assignCourierForUser(
    String orderId,
    String courierId,
    String courierName,
  ) async {
    final existing = _orderById(orderId);
    if (existing != null) {
      await _ensureMockHas(existing);
    }

    final repo = ref.read(orderRepositoryProvider);
    Order updated;
    try {
      updated = await repo.assignCourier(
        orderId,
        courierId,
        courierName,
        actorId: _actorId() ?? courierId,
        actorName: _actorName() ?? courierName,
      );
    } catch (_) {
      if (existing == null) rethrow;
      final branch = existing;
      updated = branch
          .copyWith(
            courierId: courierId,
            courierName: courierName,
          )
          .withStatus(
            OrderStatus.onTheWay,
            actorId: _actorId() ?? courierId,
            actorName: _actorName() ?? courierName,
          );
      await _ensureMockHas(updated);
    }

    await _upsertOrder(updated);
    await NotificationService.instance.notifyOrderStatus(
      OrderStatusUtils.labelKey(OrderStatus.onTheWay),
    );
    return updated;
  }

  Future<void> updateCourierLocation(
    String orderId,
    double latitude,
    double longitude,
  ) async {
    final existing = _orderById(orderId);
    if (existing != null) {
      await _ensureMockHas(existing);
    }
    final repo = ref.read(orderRepositoryProvider);
    final updated =
        await repo.updateCourierLocation(orderId, latitude, longitude);
    await _upsertOrder(updated);
  }

  Future<void> assignCourier(
    String orderId,
    String courierId,
    String courierName,
  ) async {
    await _assignCourierForUser(orderId, courierId, courierName);
  }

  Future<Order> cancelOrder(String orderId) async {
    final existing = _orderById(orderId);
    if (existing == null) {
      throw StateError('Order not found: $orderId');
    }

    final optimistic = existing.withStatus(
      OrderStatus.cancelled,
      actorId: _actorId(),
      actorName: _actorName(),
    );
    await _upsertOrder(optimistic);

    final repo = ref.read(orderRepositoryProvider);
    try {
      final updated = await repo.cancelOrder(
        orderId,
        actorId: _actorId(),
        actorName: _actorName(),
      );
      await _upsertOrder(updated);
      unawaited(NotificationService.instance.notifyOrderStatus(
        OrderStatusUtils.labelKey(OrderStatus.cancelled),
      ));
      return updated;
    } catch (_) {
      await _upsertOrder(existing);
      rethrow;
    }
  }

  Future<Order> rateOrder(
    String orderId,
    int rating, {
    String? comment,
  }) async {
    final existing = _orderById(orderId);
    if (existing != null) {
      await _ensureMockHas(existing);
    }

    final repo = ref.read(orderRepositoryProvider);
    Order updated;
    try {
      updated = await repo.rateOrder(orderId, rating, comment: comment);
    } catch (_) {
      if (existing == null) rethrow;
      updated = existing;
      await _ensureMockHas(updated);
    }

    await _upsertOrder(updated);
    return updated;
  }

  Future<void> _upsertOrder(Order updated) async {
    final current = state.value ?? [];
    var found = false;
    final list = <Order>[];
    for (final order in current) {
      if (order.id == updated.id) {
        found = true;
        list.add(updated);
      } else {
        list.add(order);
      }
    }
    if (!found) {
      list.insert(0, updated);
    }
    await _updateState(list);
    await _maybeNotifyApproach(updated);
  }

  Future<void> _maybeNotifyApproach(Order order) async {
    if (order.status != OrderStatus.onTheWay) return;
    if (order.approachNotificationSent) return;

    final auth = ref.read(authProvider);
    if (auth?.user.role != UserRole.customer) return;
    if (auth == null || !orderBelongsToCustomer(order, auth)) return;

    final minutes = DeliveryEtaUtils.minutesFromCourierToDelivery(order);
    if (minutes == null) return;

    final threshold =
        ref.read(appSettingsProvider).deliveryApproachNotifyMinutes;
    if (minutes > threshold) return;

    await NotificationService.instance.notifyApproach(minutes);
    final repo = ref.read(orderRepositoryProvider);
    final marked = await repo.markApproachNotificationSent(order.id);
    await _replaceOrderWithoutApproachCheck(marked);
  }

  Future<void> _replaceOrderWithoutApproachCheck(Order updated) async {
    final current = state.value ?? [];
    final list = [
      for (final order in current)
        if (order.id == updated.id) updated else order,
    ];
    await _updateState(list);
  }

  Future<void> refresh() async {
    await _syncFromRepository();
  }
}

final ordersProvider = AsyncNotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);

final orderByIdProvider = Provider.family<Order?, String>((ref, orderId) {
  final orders = ref.watch(ordersProvider).value ?? [];
  for (final order in orders) {
    if (order.id == orderId) return order;
  }
  return null;
});

final customerOrdersProvider = Provider<List<Order>>((ref) {
  final auth = ref.watch(authProvider);
  final orders = ref.watch(ordersProvider).value ?? [];
  if (auth == null) return [];
  return orders.where((o) => orderBelongsToCustomer(o, auth)).toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final customerActiveOrdersProvider = Provider<List<Order>>((ref) {
  return ref.watch(customerOrdersProvider).where((o) => o.isActive).toList();
});

final customerHistoryOrdersProvider = Provider<List<Order>>((ref) {
  return ref
      .watch(customerOrdersProvider)
      .where(
        (o) =>
            o.status == OrderStatus.delivered ||
            o.status == OrderStatus.cancelled,
      )
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final branchOrdersProvider = Provider<List<Order>>((ref) {
  final branch = ref.watch(managedBranchProvider).value;
  if (branch == null) return [];
  final orders = ref.watch(ordersProvider).value ?? [];
  return orders
      .where(
        (o) =>
            o.branchId == branch.id &&
            o.isDelivery &&
            o.status != OrderStatus.delivered &&
            o.status != OrderStatus.cancelled,
      )
      .toList();
});

final branchDineInOrdersProvider = Provider<List<Order>>((ref) {
  final branch = ref.watch(managedBranchProvider).value;
  if (branch == null) return [];
  final orders = ref.watch(ordersProvider).value ?? [];
  final today = DateTime.now();
  bool isToday(DateTime dt) =>
      dt.year == today.year && dt.month == today.month && dt.day == today.day;

  return orders
      .where(
        (o) => o.branchId == branch.id && o.isDineIn && isToday(o.createdAt),
      )
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

/// Mutfak ekranı: garson iç siparişleri (yeni + hazırlanıyor).
final kitchenQueueOrdersProvider = Provider<List<Order>>((ref) {
  final branch = ref.watch(managedBranchProvider).value;
  if (branch == null) return [];
  final orders = ref.watch(ordersProvider).value ?? [];
  return orders
      .where(
        (o) =>
            o.branchId == branch.id &&
            o.isDineIn &&
            (o.status == OrderStatus.received ||
                o.status == OrderStatus.preparing),
      )
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
});

/// Panel kenar çubuğu: şube personeli için şube, sistem yöneticisi için tüm şubeler.
final dashboardDineInOrdersProvider = Provider<List<Order>>((ref) {
  final auth = ref.watch(authProvider);
  final branch = ref.watch(managedBranchProvider).value;
  final orders = ref.watch(ordersProvider).value ?? [];
  final today = DateTime.now();
  bool isToday(DateTime dt) =>
      dt.year == today.year && dt.month == today.month && dt.day == today.day;

  final dineInToday =
      orders.where((o) => o.isDineIn && isToday(o.createdAt)).toList();

  if (auth?.user.role == UserRole.superAdmin) {
    return dineInToday..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  if (branch == null) return [];
  return dineInToday
      .where((o) => o.branchId == branch.id)
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final courierOrdersProvider = Provider<List<Order>>((ref) {
  final auth = ref.watch(authProvider);
  final orders = ref.watch(ordersProvider).value ?? [];
  if (auth == null) return [];
  return orders
      .where(
        (o) =>
            o.courierId == auth.user.id &&
            o.status != OrderStatus.delivered &&
            o.status != OrderStatus.cancelled,
      )
      .toList();
});

final waitingCourierOrdersProvider = Provider<List<Order>>((ref) {
  final auth = ref.watch(authProvider);
  final orders = ref.watch(ordersProvider).value ?? [];
  return orders.where((o) {
    if (o.status != OrderStatus.waitingCourier || o.courierId != null) {
      return false;
    }
    if (auth?.user.role == UserRole.courier && auth!.user.branchId != null) {
      return o.branchId == auth.user.branchId;
    }
    return true;
  }).toList();
});

final activeDeliveryOrdersProvider = Provider<List<Order>>((ref) {
  final orders = ref.watch(ordersProvider).value ?? [];
  final now = DateTime.now();
  return orders.where((o) {
    if (o.status == OrderStatus.waitingCourier ||
        o.status == OrderStatus.onTheWay) {
      return true;
    }
    final deliveredAt = o.atStatus(OrderStatus.delivered);
    return o.status == OrderStatus.delivered &&
        deliveredAt != null &&
        now.difference(deliveredAt).inHours < 2;
  }).toList();
});

final branchHistoryOrdersProvider = Provider<List<Order>>((ref) {
  final branch = ref.watch(managedBranchProvider).value;
  if (branch == null) return [];
  final orders = ref.watch(ordersProvider).value ?? [];
  return orders
      .where(
        (o) =>
            o.branchId == branch.id &&
            (o.status == OrderStatus.delivered ||
                o.status == OrderStatus.cancelled),
      )
      .toList()
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

final branchOpsAnalyticsProvider = Provider<OpsAnalytics>((ref) {
  final branch = ref.watch(managedBranchProvider).value;
  final orders = ref.watch(ordersProvider).value ?? [];
  final since = DateTime.now().subtract(const Duration(days: 30));
  return OpsAnalyticsCalculator.compute(
    orders: orders,
    branchId: branch?.id,
    since: since,
  );
});

final adminOpsAnalyticsProvider = Provider<OpsAnalytics>((ref) {
  final orders = ref.watch(ordersProvider).value ?? [];
  final since = DateTime.now().subtract(const Duration(days: 30));
  return OpsAnalyticsCalculator.compute(orders: orders, since: since);
});

final branchDailyStatsProvider = Provider<({double revenue, int count})>((ref) {
  final branch = ref.watch(managedBranchProvider).value;
  if (branch == null) return (revenue: 0, count: 0);
  final orders = ref.watch(ordersProvider).value ?? [];
  final today = DateTime.now();
  final todayOrders = orders.where((o) {
    return o.branchId == branch.id &&
        o.createdAt.year == today.year &&
        o.createdAt.month == today.month &&
        o.createdAt.day == today.day;
  });
  final revenue = todayOrders.fold<double>(0, (sum, o) => sum + o.totalAmount);
  return (revenue: revenue, count: todayOrders.length);
});
