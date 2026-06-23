import 'package:easy_localization/easy_localization.dart';

import '../localization/locale_keys.dart';
import '../../shared/domain/entities/order.dart';

abstract final class OrderStatusUtils {
  /// Normal teslimat hattı — iptal hariç.
  static const List<OrderStatus> fulfillmentPipeline = [
    OrderStatus.received,
    OrderStatus.preparing,
    OrderStatus.waitingCourier,
    OrderStatus.onTheWay,
    OrderStatus.delivered,
  ];

  static String labelKey(OrderStatus status) {
    return switch (status) {
      OrderStatus.received => LocaleKeys.orderStatusReceived,
      OrderStatus.preparing => LocaleKeys.orderStatusPreparing,
      OrderStatus.waitingCourier => LocaleKeys.orderStatusWaitingCourier,
      OrderStatus.onTheWay => LocaleKeys.orderStatusOnTheWay,
      OrderStatus.delivered => LocaleKeys.orderStatusDelivered,
      OrderStatus.cancelled => LocaleKeys.orderStatusCancelled,
    };
  }

  static String label(OrderStatus status) => labelKey(status).tr();

  static int stepIndex(OrderStatus status) => fulfillmentStepIndex(status);

  static int fulfillmentStepIndex(OrderStatus status) {
    if (status == OrderStatus.cancelled) return -1;
    return fulfillmentPipeline.indexOf(status);
  }

  static bool isInFulfillment(OrderStatus status) {
    return status != OrderStatus.delivered && status != OrderStatus.cancelled;
  }

  static bool isPastFulfillmentStep(OrderStatus step, OrderStatus current) {
    final stepIdx = fulfillmentStepIndex(step);
    final currentIdx = fulfillmentStepIndex(current);
    if (stepIdx < 0 || currentIdx < 0) return false;
    return stepIdx < currentIdx;
  }

  /// İş akışında izin verilen durum geçişleri.
  static bool isValidTransition(OrderStatus from, OrderStatus to) {
    if (to == OrderStatus.cancelled) {
      return from == OrderStatus.received || from == OrderStatus.preparing;
    }
    if (from == OrderStatus.cancelled || from == OrderStatus.delivered) {
      return false;
    }
    if (to == OrderStatus.delivered) {
      return from == OrderStatus.onTheWay || isDineInBillCloseStatus(from);
    }
    if (to == OrderStatus.onTheWay) {
      return from == OrderStatus.waitingCourier;
    }
    final fromIdx = fulfillmentStepIndex(from);
    final toIdx = fulfillmentStepIndex(to);
    if (fromIdx < 0 || toIdx < 0) return false;
    return toIdx == fromIdx + 1;
  }

  /// Salon siparişi hesap kapatma: mutfak hazırlığından doğrudan kapatıldı.
  static bool isDineInBillCloseStatus(OrderStatus from) {
    return from == OrderStatus.preparing || from == OrderStatus.received;
  }

  static List<String> get allStepKeys => [
        LocaleKeys.orderStatusReceived,
        LocaleKeys.orderStatusPreparing,
        LocaleKeys.orderStatusWaitingCourier,
        LocaleKeys.orderStatusOnTheWay,
        LocaleKeys.orderStatusDelivered,
      ];
}
