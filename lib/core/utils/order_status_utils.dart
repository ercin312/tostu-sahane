import 'package:easy_localization/easy_localization.dart';

import '../localization/locale_keys.dart';
import '../../shared/domain/entities/order.dart';

abstract final class OrderStatusUtils {
  /// Paket servis teslimat hattı — iptal hariç.
  static const List<OrderStatus> fulfillmentPipeline = [
    OrderStatus.received,
    OrderStatus.preparing,
    OrderStatus.waitingCourier,
    OrderStatus.onTheWay,
    OrderStatus.delivered,
  ];

  /// Salon / iç sipariş hattı — kurye adımları yok.
  static const List<OrderStatus> dineInPipeline = [
    OrderStatus.received,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.delivered,
  ];

  static List<OrderStatus> pipelineFor(Order order) {
    return order.isDineIn ? dineInPipeline : fulfillmentPipeline;
  }

  static String labelKey(OrderStatus status) {
    return switch (status) {
      OrderStatus.received => LocaleKeys.orderStatusReceived,
      OrderStatus.preparing => LocaleKeys.orderStatusPreparing,
      OrderStatus.ready => LocaleKeys.orderStatusReady,
      OrderStatus.waitingCourier => LocaleKeys.orderStatusWaitingCourier,
      OrderStatus.onTheWay => LocaleKeys.orderStatusOnTheWay,
      OrderStatus.delivered => LocaleKeys.orderStatusDelivered,
      OrderStatus.cancelled => LocaleKeys.orderStatusCancelled,
    };
  }

  static String label(OrderStatus status) => labelKey(status).tr();

  /// Sipariş türüne göre kullanıcıya gösterilecek durum metni.
  static String labelFor(Order order) {
    if (order.phoneFailed) {
      return LocaleKeys.branchPhoneOrderFailedBadge.tr();
    }
    if (order.isDineIn) {
      return switch (order.status) {
        OrderStatus.ready => LocaleKeys.orderStatusReady.tr(),
        OrderStatus.waitingCourier || OrderStatus.onTheWay =>
          LocaleKeys.orderStatusReady.tr(),
        _ => label(order.status),
      };
    }
    return label(order.status);
  }

  static int stepIndex(OrderStatus status, {bool dineIn = false}) =>
      fulfillmentStepIndex(status, dineIn: dineIn);

  static int fulfillmentStepIndex(OrderStatus status, {bool dineIn = false}) {
    if (status == OrderStatus.cancelled) return -1;
    final pipeline = dineIn ? dineInPipeline : fulfillmentPipeline;
    final idx = pipeline.indexOf(status);
    if (idx >= 0) return idx;
    if (dineIn &&
        (status == OrderStatus.waitingCourier ||
            status == OrderStatus.onTheWay)) {
      return dineInPipeline.indexOf(OrderStatus.ready);
    }
    return -1;
  }

  static bool isInFulfillment(OrderStatus status) {
    return status != OrderStatus.delivered && status != OrderStatus.cancelled;
  }

  static bool isPastFulfillmentStep(
    OrderStatus step,
    OrderStatus current, {
    bool dineIn = false,
  }) {
    final stepIdx = fulfillmentStepIndex(step, dineIn: dineIn);
    final currentIdx = fulfillmentStepIndex(current, dineIn: dineIn);
    if (stepIdx < 0 || currentIdx < 0) return false;
    return stepIdx < currentIdx;
  }

  /// İş akışında izin verilen durum geçişleri.
  static bool isValidTransition(
    OrderStatus from,
    OrderStatus to, {
    bool dineIn = false,
  }) {
    if (to == OrderStatus.cancelled) {
      return from == OrderStatus.received || from == OrderStatus.preparing;
    }
    if (from == OrderStatus.cancelled || from == OrderStatus.delivered) {
      return false;
    }
    if (dineIn) {
      if (to == OrderStatus.ready) {
        return from == OrderStatus.preparing || from == OrderStatus.received;
      }
      if (to == OrderStatus.delivered) {
        return isDineInBillCloseStatus(from) || from == OrderStatus.ready;
      }
      final fromIdx = fulfillmentStepIndex(from, dineIn: true);
      final toIdx = fulfillmentStepIndex(to, dineIn: true);
      if (fromIdx < 0 || toIdx < 0) return false;
      return toIdx == fromIdx + 1;
    }
    if (to == OrderStatus.delivered) {
      return from == OrderStatus.onTheWay;
    }
    if (to == OrderStatus.onTheWay) {
      return from == OrderStatus.waitingCourier;
    }
    if (to == OrderStatus.ready) return false;
    final fromIdx = fulfillmentStepIndex(from);
    final toIdx = fulfillmentStepIndex(to);
    if (fromIdx < 0 || toIdx < 0) return false;
    return toIdx == fromIdx + 1;
  }

  /// Salon siparişi hesap kapatma.
  static bool isDineInBillCloseStatus(OrderStatus from) {
    return from == OrderStatus.preparing ||
        from == OrderStatus.received ||
        from == OrderStatus.ready;
  }

  static List<String> stepKeysFor(Order order) {
    return pipelineFor(order)
        .map((status) => labelKey(status))
        .toList(growable: false);
  }

  static List<String> get allStepKeys => [
        LocaleKeys.orderStatusReceived,
        LocaleKeys.orderStatusPreparing,
        LocaleKeys.orderStatusWaitingCourier,
        LocaleKeys.orderStatusOnTheWay,
        LocaleKeys.orderStatusDelivered,
      ];
}
