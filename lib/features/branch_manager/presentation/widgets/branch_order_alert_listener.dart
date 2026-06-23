import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/printing/cashier_printer_provider.dart';
import '../../../../core/printing/kitchen_printer_provider.dart';
import '../../../../core/printing/order_receipt_printer.dart';
import '../../../../core/printing/print_routing_utils.dart';
import '../../../../core/services/branch_alert_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/platform_layout_utils.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/customer/home/presentation/providers/branch_provider.dart';
import '../../../../shared/domain/entities/branch.dart';
import '../../../../shared/domain/entities/print_routing_settings.dart';
import '../../../../shared/domain/entities/order.dart';
import '../../../../shared/domain/entities/user.dart';
import '../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../shared/presentation/providers/print_routing_settings_provider.dart';
import '../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';

/// Şube ekranlarında yeni sipariş geldiğinde ses, snackbar ve otomatik fiş yazdırır.
class BranchOrderAlertListener extends ConsumerStatefulWidget {
  const BranchOrderAlertListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BranchOrderAlertListener> createState() =>
      _BranchOrderAlertListenerState();
}

class _BranchOrderAlertListenerState
    extends ConsumerState<BranchOrderAlertListener> {
  static const _sessionGrace = Duration(seconds: 5);

  final _seenReceivedOrderIds = <String>{};
  final _seenDineInOrderIds = <String>{};
  final _printedOrderIds = <String>{};
  var _initialized = false;
  late final DateTime _sessionStartedAt;

  @override
  void initState() {
    super.initState();
    _sessionStartedAt = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(kitchenPrinterProvider.notifier).load());
      unawaited(ref.read(cashierPrinterProvider.notifier).load());
    });
  }

  String? _managedBranchId() {
    final auth = ref.read(authProvider);
    if (auth == null) return null;
    if (auth.user.role == UserRole.branchManager ||
        auth.user.role == UserRole.branchStaff ||
        auth.user.role == UserRole.waiter ||
        auth.user.role == UserRole.kitchenStaff) {
      return auth.user.branchId ??
          ref.read(managedBranchProvider).value?.id;
    }
    return null;
  }

  List<Order> _branchOrders(List<Order> orders) {
    final branchId = _managedBranchId();
    if (branchId == null) return const [];
    return orders
        .where(
          (o) =>
              o.branchId == branchId &&
              o.status != OrderStatus.delivered &&
              o.status != OrderStatus.cancelled,
        )
        .toList();
  }

  bool _isOrderFromCurrentSession(Order order) {
    return !order.createdAt.isBefore(_sessionStartedAt.subtract(_sessionGrace));
  }

  void _resetForBranchChange() {
    _seenReceivedOrderIds.clear();
    _seenDineInOrderIds.clear();
    _printedOrderIds.clear();
    _initialized = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Order>>>(ordersProvider, (previous, next) {
      if (!next.hasValue) return;
      _onBranchOrdersUpdated(_branchOrders(next.value ?? []));
    });

    ref.listen<AsyncValue<Branch?>>(managedBranchProvider, (previous, next) {
      if (!next.hasValue) return;
      final prevId = previous?.value?.id;
      final nextId = next.value?.id;
      if (prevId != null && nextId != null && prevId != nextId) {
        _resetForBranchChange();
      }
      if (!ref.read(ordersProvider).hasValue) return;
      _onBranchOrdersUpdated(
        _branchOrders(ref.read(ordersProvider).value ?? []),
      );
    });

    return widget.child;
  }

  void _onBranchOrdersUpdated(List<Order> orders) {
    if (_managedBranchId() == null) return;

    if (!_initialized) {
      _seedInitialOrders(orders);
      _initialized = true;
      return;
    }

    _handleDineInOrders(orders);
    _handleDeliveryReceived(orders);
  }

  void _seedInitialOrders(List<Order> orders) {
    for (final order in orders.where((o) => o.isDineIn)) {
      _seenDineInOrderIds.add(order.id);
      _printedOrderIds.add(order.id);
    }

    for (final order in orders.where(
      (o) => o.isDelivery && o.status == OrderStatus.received,
    )) {
      _seenReceivedOrderIds.add(order.id);
      _printedOrderIds.add(order.id);
    }
  }

  void _handleDineInOrders(List<Order> orders) {
    final dineIn = orders.where((o) => o.isDineIn).toList();
    final dineInIds = dineIn.map((o) => o.id).toSet();

    final newIds = dineInIds.difference(_seenDineInOrderIds);
    if (newIds.isEmpty) return;

    _seenDineInOrderIds.addAll(newIds);
    final newOrders = dineIn
        .where(
          (o) => newIds.contains(o.id) && _isOrderFromCurrentSession(o),
        )
        .toList(growable: false);
    if (newOrders.isEmpty) return;

    BranchAlertService.playNewOrderAlert();

    final toPrint = newOrders.where(_shouldAutoPrint).toList(growable: false);
    if (toPrint.isNotEmpty) {
      unawaited(_printOrders(toPrint));
    } else {
      for (final order in newOrders) {
        _printedOrderIds.add(order.id);
      }
    }
  }

  void _handleDeliveryReceived(List<Order> orders) {
    final received =
        orders.where((o) => o.isDelivery && o.status == OrderStatus.received).toList();
    final receivedIds = received.map((o) => o.id).toSet();

    final newIds = receivedIds.difference(_seenReceivedOrderIds);
    if (newIds.isEmpty) return;

    _seenReceivedOrderIds.addAll(newIds);
    final newOrders = received
        .where(
          (o) => newIds.contains(o.id) && _isOrderFromCurrentSession(o),
        )
        .toList(growable: false);
    if (newOrders.isEmpty) return;

    BranchAlertService.playNewOrderAlert();

    final toPrint = newOrders.where(_shouldAutoPrint).toList(growable: false);
    if (toPrint.isNotEmpty) {
      unawaited(_printOrders(toPrint));
    } else {
      for (final order in newOrders) {
        _printedOrderIds.add(order.id);
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        content: Text(
          LocaleKeys.branchNewOrderAlert.tr(namedArgs: {
            'count': '${newOrders.length}',
          }),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  bool _shouldAutoPrint(Order order) {
    final auth = ref.read(authProvider);
    if (auth == null) return false;

    final routing =
        ref.read(printRoutingSettingsProvider).valueOrNull ??
            PrintRoutingSettings.defaults;
    final dineInEnabled = ref
            .read(waiterModeSettingsProvider)
            .valueOrNull
            ?.printKitchenReceiptOnWaiterOrder ??
        true;

    return PrintRoutingUtils.shouldAutoPrint(
      order: order,
      role: auth.user.role,
      routing: routing,
      dineInPrintingEnabled: dineInEnabled,
    );
  }

  String? _printerForCurrentRole() {
    final auth = ref.read(authProvider);
    if (auth == null) return null;

    final routing =
        ref.read(printRoutingSettingsProvider).valueOrNull ??
            PrintRoutingSettings.defaults;

    return PrintRoutingUtils.resolvePrinterName(
      role: auth.user.role,
      routing: routing,
      localKitchenPrinter: ref.read(kitchenPrinterProvider),
      localCashierPrinter: ref.read(cashierPrinterProvider),
    );
  }

  Future<void> _printOrders(List<Order> orders) async {
    final savedPrinter = _printerForCurrentRole();
    for (final order in orders) {
      if (_printedOrderIds.contains(order.id)) continue;
      _printedOrderIds.add(order.id);

      final ok = await OrderReceiptPrinter.autoPrintKitchenReceipt(
        order,
        savedPrinterName: savedPrinter,
      );

      if (!mounted || !PlatformLayout.isOpsDesktop) continue;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok ? AppColors.success : AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: ok ? 3 : 6),
          content: Text(
            ok
                ? LocaleKeys.receiptAutoPrintSuccess.tr(namedArgs: {
                    'number': '${order.orderNumber}',
                  })
                : LocaleKeys.receiptAutoPrintFailed.tr(),
          ),
        ),
      );
    }
  }
}
