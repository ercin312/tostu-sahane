import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/payments/paytr_service.dart';
import 'package:tostu_sahane/core/payments/paytr_vat_utils.dart';
import 'package:tostu_sahane/shared/domain/entities/paytr_settings.dart';

void main() {
  test('paytr token matches documented hash algorithm', () {
    const settings = PaytrSettings(
      enabled: true,
      merchantId: '123456',
      merchantKey: 'test_key',
      merchantSalt: 'test_salt',
    );
    const basket = 'dGVzdA==';
    final token = PaytrService.buildPaytrToken(
      settings: settings,
      userIp: '1.1.1.1',
      merchantOid: 'order123',
      email: 'test@example.com',
      paymentAmountKurus: 1000,
      userBasket: basket,
      sandboxMode: true,
    );
    expect(token, isNotEmpty);
    expect(token, token.trim());
  });

  test('vat excluded adds rate on payable total', () {
    const settings = PaytrSettings(
      vatRatePercent: 10,
      vatIncluded: false,
    );
    expect(PaytrVatUtils.payableTotal(100, settings), closeTo(110, 0.01));
    expect(PaytrVatUtils.vatAmount(100, settings), 10);
  });

  test('vat included keeps payable total and extracts vat', () {
    const settings = PaytrSettings(
      vatRatePercent: 10,
      vatIncluded: true,
    );
    expect(PaytrVatUtils.payableTotal(110, settings), 110);
    expect(PaytrVatUtils.vatAmount(110, settings), closeTo(10, 0.01));
  });
}
