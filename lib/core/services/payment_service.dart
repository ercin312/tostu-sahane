import '../localization/locale_keys.dart';
import '../../shared/domain/entities/order.dart';

abstract final class PaymentService {
  static const demoCardNumber = '4242424242424242';

  static Future<PaymentResult> processCardPayment({
    required double amount,
    required String cardNumber,
    required String expiry,
    required String cvv,
    required String cardHolder,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 2));

    final normalized = cardNumber.replaceAll(RegExp(r'\s|-'), '');
    if (normalized != demoCardNumber) {
      throw const PaymentException(LocaleKeys.paymentInvalidCard);
    }
    if (expiry.length < 4) {
      throw const PaymentException(LocaleKeys.paymentInvalidExpiry);
    }
    if (cvv.length < 3) {
      throw const PaymentException(LocaleKeys.paymentInvalidCvv);
    }
    if (cardHolder.trim().length < 3) {
      throw const PaymentException(LocaleKeys.paymentInvalidHolder);
    }

    return PaymentResult(
      transactionId: 'txn_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
    );
  }

  /// Kayıtlı kart ile demo ödeme — sadece CVV doğrulanır.
  static Future<PaymentResult> processSavedCardPayment({
    required double amount,
    required String cvv,
    required String lastFour,
  }) async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (cvv.length < 3) {
      throw const PaymentException(LocaleKeys.paymentInvalidCvv);
    }
    if (lastFour.length != 4) {
      throw const PaymentException(LocaleKeys.paymentInvalidCard);
    }
    return PaymentResult(
      transactionId: 'txn_saved_${DateTime.now().millisecondsSinceEpoch}',
      amount: amount,
    );
  }
}
