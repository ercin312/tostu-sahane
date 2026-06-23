import 'package:easy_localization/easy_localization.dart';

import '../localization/locale_keys.dart';
import '../../shared/domain/entities/order.dart';

abstract final class PaymentMethodUtils {
  static String labelKey(PaymentMethod method) {
    return switch (method) {
      PaymentMethod.onlineCard => LocaleKeys.checkoutPaymentCard,
      PaymentMethod.cashOnDelivery => LocaleKeys.checkoutPaymentCash,
      PaymentMethod.cardOnDelivery => LocaleKeys.checkoutPaymentCardDoor,
    };
  }

  static String label(PaymentMethod method) => labelKey(method).tr();
}
