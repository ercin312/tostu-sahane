import '../../shared/domain/entities/paytr_settings.dart';

abstract final class PaytrVatUtils {
  static double payableTotal(double subtotalAfterDiscount, PaytrSettings settings) {
    if (settings.vatIncluded) return subtotalAfterDiscount;
    return subtotalAfterDiscount * (1 + settings.vatRatePercent / 100);
  }

  static double vatAmount(double subtotalAfterDiscount, PaytrSettings settings) {
    if (subtotalAfterDiscount <= 0) return 0;
    final rate = settings.vatRatePercent / 100;
    if (settings.vatIncluded) {
      return subtotalAfterDiscount - (subtotalAfterDiscount / (1 + rate));
    }
    return subtotalAfterDiscount * rate;
  }
}
