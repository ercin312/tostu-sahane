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

/// Şube ekranlarında yeni sipariş geldiğinde ses, snackbar ve otomatik fiş yazdırır.
///
/// Açılışta mevcut siparişler ASLA yazdırılmaz. Yalnızca uygulama açıldıktan sonra
/// ilk kez görülen siparişler basılır.
class BranchOrderAlertListener extends ConsumerStatefulWidget {
  const BranchOrderAlertListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BranchOrderAlertListener> createState() =>
      _BranchOrderAlertListenerState();
}

class _BranchOrderAlertListenerState
    extends ConsumerState<BranchOrderAlertListener> {
  /// İlk dolu poll veya bu süre sonrası: yazdırma açık.
  static const _bootstrapMaxWait = Duration(seconds: 12);

  final _knownOrderIds = <String>{};
  final _printedOrderIds = <String>{};
  final _printedPhoneItemCounts = <String, int>{};
  final _printedCancelIds = <String>{};
  final _alertedInquiryIds = <String>{};
  var _bootstrapped = false;
  late final DateTime _sessionStartedAt;

  @override
  void initState() {
    super.initState();
    _sessionStartedAt = DateTime.now().toUtc();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(kitchenPrinterProvider.notifier).load());
      unawaited(ref.read(cashierPrinterProvider.notifier).load());
      // Mevcut snapshot varsa hemen bootstrap’a al (listen ilk değeri vermeyebilir).
      final current = ref.read(ordersProvider).value;
      if (current != null) {
        _onBranchOrdersUpdated(_branchOrders(current));
      }
    });
  }

  String? _managedBranchId() {
    final auth = ref.read(authProvider);
    if (auth == null) return null;
    if (auth.user.role == UserRole.branchManager ||
        auth.user.role == UserRole.branchStaff ||
        auth.user.role == UserRole.waiter ||
        auth.user.role == UserRole.kitchenStaff ||
        auth.user.role == UserRole.superAdmin) {
      return auth.user.branchId ??
          ref.read(managedBranchProvider).value?.id;
    }
    return null;
  }

  List<Order> _branchOrders(List<Order> orders) {
    final branchId = _managedBranchId();
    final auth = ref.read(authProvider);
    if (branchId == null) {
      if (auth?.user.role == UserRole.superAdmin) {
        return orders
            .where(
              (o) =>
                  o.isPhoneOrder &&
                  !o.phoneFailed &&
                  o.status != OrderStatus.delivered &&
                  o.status != OrderStatus.cancelled,
            )
            .toList();
      }
      return const [];
    }
    return orders
        .where(
          (o) =>
              o.branchId == branchId &&
              !o.phoneFailed &&
              o.status != OrderStatus.delivered &&
              o.status != OrderStatus.cancelled,
        )
        .toList();
  }

  // Bootstrap: açılıştaki inquiry'leri “görüldü” say (eski uyarı basma).
  void _absorbAsKnown(Iterable<Order> orders) {
    for (final order in orders) {
      _knownOrderIds.add(order.id);
      _printedOrderIds.add(order.id);
      if (order.isPhoneOrder) {
        _printedPhoneItemCounts[order.id] = order.items.length;
      }
      if (order.phoneStatusInquiry) {
        _alertedInquiryIds.add(order.id);
      }
      if (order.phoneCancelPrintPending) {
        _printedCancelIds.add(order.id);
      }
    }
  }

  bool _createdAfterAppOpen(Order order) {
    final created = order.createdAt.toUtc();
    // Ağ gecikmesi için 2 sn tolerans; eski siparişler geçmez.
    return !created.isBefore(_sessionStartedAt.subtract(const Duration(seconds: 2)));
  }

  void _resetForBranchChange() {
    _knownOrderIds.clear();
    _printedOrderIds.clear();
    _printedPhoneItemCounts.clear();
    _printedCancelIds.clear();
    _alertedInquiryIds.clear();
    _bootstrapped = false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Order>>>(ordersProvider, (previous, next) {
      if (!next.hasValue) return;
      final all = next.value ?? [];
      _onBranchOrdersUpdated(_branchOrders(all));
      _onPhoneSpecialEvents(all);
    });

    ref.listen<AsyncValue<Branch?>>(managedBranchProvider, (previous, next) {
      if (!next.hasValue) return;
      final prevId = previous?.value?.id;
      final nextId = next.value?.id;
      if (prevId != null && nextId != null && prevId != nextId) {
        _resetForBranchChange();
      }
      if (!ref.read(ordersProvider).hasValue) return;
      final all = ref.read(ordersProvider).value ?? [];
      _onBranchOrdersUpdated(_branchOrders(all));
      _onPhoneSpecialEvents(all);
    });

    return widget.child;
  }

  void _onPhoneSpecialEvents(List<Order> all) {
    if (!_bootstrapped) return;
    final branchId = _managedBranchId();
    final auth = ref.read(authProvider);
    final canListenWithoutBranch =
        auth?.user.role == UserRole.superAdmin && branchId == null;
    if (branchId == null && !canListenWithoutBranch) return;

    for (final order in all) {
      if (branchId != null && order.branchId != branchId) continue;
      if (!order.isPhoneOrder) continue;

      if (order.phoneCancelPrintPending &&
          order.status == OrderStatus.cancelled &&
          !_printedCancelIds.contains(order.id) &&
          _createdAfterAppOpen(order)) {
        _printedCancelIds.add(order.id);
        BranchAlertService.playNewOrderAlert();
        unawaited(_printOrders([order], force: true));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              content: Text(
                LocaleKeys.branchPhoneOrderCancelledAlert.tr(
                  namedArgs: {
                    'number': '${order.orderNumber}',
                    'reason': order.phoneCancelReason?.trim().isNotEmpty == true
                        ? order.phoneCancelReason!.trim()
                        : '-',
                  },
                ),
              ),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }

      if (order.phoneStatusInquiry &&
          !_alertedInquiryIds.contains(order.id)) {
        _alertedInquiryIds.add(order.id);
        BranchAlertService.playNewOrderAlert();
        if (mounted) {
          final mins = order.phoneStatusInquiryMinutes;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
              content: Text(
                LocaleKeys.branchPhoneOrderInquiryAlert.tr(
                  namedArgs: {
                    'number': '${order.orderNumber}',
                    'minutes': mins != null ? '$mins' : '?',
                    'note': order.phoneStatusInquiryNote?.trim().isNotEmpty ==
                            true
                        ? order.phoneStatusInquiryNote!.trim()
                        : LocaleKeys.branchPhoneOrderInquiryDefault.tr(),
                  },
                ),
              ),
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }
    }
  }

  void _onBranchOrdersUpdated(List<Order> orders) {
    final auth = ref.read(authProvider);
    final canListenWithoutBranch =
        auth?.user.role == UserRole.superAdmin && _managedBranchId() == null;
    if (_managedBranchId() == null && !canListenWithoutBranch) return;

    // Bootstrap: açılıştaki tüm siparişleri “bilinen” yap, yazdırma.
    if (!_bootstrapped) {
      _absorbAsKnown(orders);
      final waitedEnough =
          DateTime.now().toUtc().difference(_sessionStartedAt) >=
              _bootstrapMaxWait;
      if (orders.isNotEmpty || waitedEnough) {
        _bootstrapped = true;
      }
      return;
    }

    // Bootstrap sonrası ilk kez görülen + uygulama açılışından sonra oluşan
    final brandNew = <Order>[];
    for (final order in orders) {
      if (_knownOrderIds.contains(order.id)) {
        _maybeReprintPhoneItemGrowth(order);
        continue;
      }
      _knownOrderIds.add(order.id);
      if (_createdAfterAppOpen(order)) {
        brandNew.add(order);
      } else {
        // Eski sipariş sonradan poll’a düştü — basma.
        _printedOrderIds.add(order.id);
        if (order.isPhoneOrder) {
          _printedPhoneItemCounts[order.id] = order.items.length;
        }
      }
    }

    if (brandNew.isEmpty) return;

    final printable = brandNew.where((o) {
      if (o.phoneFailed) return false;
      if (o.status == OrderStatus.cancelled) {
        return o.isPhoneOrder && o.phoneCancelPrintPending;
      }
      if (o.items.isEmpty) return false;
      if (!_shouldAutoPrint(o)) return false;
      if (o.isDelivery) {
        return o.status == OrderStatus.received;
      }
      if (o.isDineIn) {
        if (o.isTableAddon) return false;
        return o.status == OrderStatus.received ||
            o.status == OrderStatus.preparing;
      }
      return false;
    }).toList(growable: false);

    if (printable.isEmpty) {
      for (final order in brandNew) {
        _printedOrderIds.add(order.id);
      }
      return;
    }

    BranchAlertService.playNewOrderAlert();
    unawaited(_printOrders(printable));

    if (!mounted) return;
    final deliveryNew = brandNew.where((o) => o.isDelivery).length;
    if (deliveryNew > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          content: Text(
            LocaleKeys.branchNewOrderAlert.tr(namedArgs: {
              'count': '$deliveryNew',
            }),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _maybeReprintPhoneItemGrowth(Order order) {
    if (!order.isPhoneOrder || order.phoneFailed) return;
    if (!order.isDelivery || order.status != OrderStatus.received) return;
    if (order.items.isEmpty || !_shouldAutoPrint(order)) return;
    if (!_createdAfterAppOpen(order)) return;

    final prev = _printedPhoneItemCounts[order.id];
    if (prev == null) {
      _printedPhoneItemCounts[order.id] = order.items.length;
      return;
    }
    if (order.items.length <= prev) return;
    if (!_printedOrderIds.contains(order.id)) return;

    _printedOrderIds.remove(order.id);
    _printedPhoneItemCounts[order.id] = order.items.length;
    BranchAlertService.playNewOrderAlert();
    unawaited(_printOrders([order]));
  }

  bool _shouldAutoPrint(Order order) {
    final auth = ref.read(authProvider);
    if (auth == null) return false;

    final routing =
        ref.read(printRoutingSettingsProvider).valueOrNull ??
            PrintRoutingSettings.defaults;
    return PrintRoutingUtils.shouldAutoPrint(
      order: order,
      role: auth.user.role,
      routing: routing,
    );
  }

  String? _printerForOrder(Order order) {
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
      order: order,
    );
  }

  Future<void> _printOrders(List<Order> orders, {bool force = false}) async {
    for (final order in orders) {
      if (!force && _printedOrderIds.contains(order.id)) continue;
      _printedOrderIds.add(order.id);
      if (order.isPhoneOrder) {
        _printedPhoneItemCounts[order.id] = order.items.length;
      }

      final ok = await OrderReceiptPrinter.autoPrintKitchenReceipt(
        order,
        savedPrinterName: _printerForOrder(order),
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
