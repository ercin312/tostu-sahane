import '../../domain/entities/order.dart';
import '../models/payment_models.dart';
import '../datasources/mock_api_datasource.dart';
import '../datasources/remote/payment_remote_datasource.dart';
import '../../../core/config/app_config.dart';
import '../../../core/payments/paytr_service.dart';
import '../../domain/entities/paytr_settings.dart';

class PaymentRepository {
  PaymentRepository({
    required PaymentRemoteDataSource remote,
    required MockApiDataSource mock,
    PaytrService? paytrService,
  })  : _remote = remote,
        _mock = mock,
        _paytrService = paytrService ?? PaytrService();

  final PaymentRemoteDataSource _remote;
  final MockApiDataSource _mock;
  final PaytrService _paytrService;

  Future<PaytrInitModel> initPaytr(
    PaytrInitRequest request, {
    PaytrSettings? settings,
    List<CartItem> items = const [],
  }) async {
    if (AppConfig.useMockApi) {
      return _mock.initPaytr(request);
    }
    if (settings != null && settings.isConfigured) {
      return _paytrService.initPayment(
        request: request,
        settings: settings,
        items: items,
      );
    }
    return _remote.initPaytr(request);
  }

  Future<PaymentResult> verifyPaytr(
    String merchantOid,
    double amount, {
    PaytrSettings? settings,
  }) async {
    if (AppConfig.useMockApi) {
      return _mock.verifyPaytr(merchantOid, amount);
    }
    if (settings != null && settings.isConfigured) {
      return PaymentResult(
        transactionId: merchantOid,
        amount: amount,
      );
    }
    final result = await _remote.verifyPaytr(merchantOid);
    if (!result.isSuccess) {
      throw const PaymentException('payment_paytr_failed');
    }
    return PaymentResult(
      transactionId: result.transactionId,
      amount: amount,
    );
  }
}

String buildPaytrMerchantOid() =>
    'ts_${DateTime.now().millisecondsSinceEpoch}';

String buildPaytrBasketSummary(List<CartItem> items) {
  return items
      .map((item) => '${item.productNameKey} x${item.quantity}')
      .join(', ');
}
