import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../shared/data/models/payment_models.dart';
import '../../shared/domain/entities/order.dart';
import '../../shared/domain/entities/paytr_settings.dart';
import '../config/app_config.dart';
import '../utils/localized_text.dart';

class PaytrService {
  PaytrService({Dio? dio}) : _dio = dio ?? Dio(_baseOptions);

  static const _tokenUrl = 'https://www.paytr.com/odeme/api/get-token';

  static BaseOptions get _baseOptions => BaseOptions(
        connectTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
        headers: const {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
      );

  final Dio _dio;

  Future<PaytrInitModel> initPayment({
    required PaytrInitRequest request,
    required PaytrSettings settings,
    required List<CartItem> items,
  }) async {
    if (!settings.isConfigured) {
      throw StateError('paytr_not_configured');
    }

    final userIp = await _resolveUserIp();
    final paymentAmount = (request.amount * 100).round();
    final userBasket = _encodeUserBasket(items);
    final testMode = settings.sandboxMode ? '1' : '0';
    const noInstallment = '0';
    const maxInstallment = '0';
    const currency = 'TL';

    final hashStr = settings.merchantId.trim() +
        userIp +
        request.merchantOid +
        request.email.trim() +
        '$paymentAmount' +
        userBasket +
        noInstallment +
        maxInstallment +
        currency +
        testMode;

    final token = base64Encode(
      Hmac(sha256, utf8.encode(settings.merchantKey.trim()))
          .convert(utf8.encode(hashStr + settings.merchantSalt.trim()))
          .bytes,
    );

    final okUrl = _resolveUrl(
      settings.successRedirectUrl,
      AppConfig.paytrSuccessUrl,
    );
    final failUrl = _resolveUrl(
      settings.failRedirectUrl,
      AppConfig.paytrFailUrl,
    );

    final body = <String, String>{
      'merchant_id': settings.merchantId.trim(),
      'user_ip': userIp,
      'merchant_oid': request.merchantOid,
      'email': request.email.trim(),
      'payment_amount': '$paymentAmount',
      'paytr_token': token,
      'user_basket': userBasket,
      'debug_on': settings.sandboxMode ? '1' : '0',
      'no_installment': noInstallment,
      'max_installment': maxInstallment,
      'user_name': request.customerName,
      'user_address': request.address,
      'user_phone': request.phone,
      'merchant_ok_url': okUrl,
      'merchant_fail_url': failUrl,
      'timeout_limit': '30',
      'currency': currency,
      'test_mode': testMode,
      'iframe_v2': '1',
    };

    final response = await _dio.post<Map<String, dynamic>>(
      _tokenUrl,
      data: body,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final data = response.data ?? const {};
    final status = data['status']?.toString();
    if (status != 'success') {
      final reason = data['reason']?.toString() ?? 'unknown';
      debugPrint('PayTR get-token failed: $reason');
      throw StateError('payment_paytr_init_failed');
    }

    final iframeToken = data['token']?.toString();
    if (iframeToken == null || iframeToken.isEmpty) {
      throw StateError('payment_paytr_init_failed');
    }

    return PaytrInitModel(
      merchantOid: request.merchantOid,
      iframeToken: iframeToken,
      iframeUrl: 'https://www.paytr.com/odeme/guvenli/$iframeToken',
    );
  }

  static String buildPaytrToken({
    required PaytrSettings settings,
    required String userIp,
    required String merchantOid,
    required String email,
    required int paymentAmountKurus,
    required String userBasket,
    required bool sandboxMode,
  }) {
    const noInstallment = '0';
    const maxInstallment = '0';
    const currency = 'TL';
    final testMode = sandboxMode ? '1' : '0';
    final hashStr = settings.merchantId.trim() +
        userIp +
        merchantOid +
        email.trim() +
        '$paymentAmountKurus' +
        userBasket +
        noInstallment +
        maxInstallment +
        currency +
        testMode;
    return base64Encode(
      Hmac(sha256, utf8.encode(settings.merchantKey.trim()))
          .convert(utf8.encode(hashStr + settings.merchantSalt.trim()))
          .bytes,
    );
  }

  static String encodeUserBasket(List<CartItem> items) {
    final rows = items
        .map(
          (item) => [
            localizedOrRaw(item.productNameKey),
            (item.unitPrice * item.quantity).toStringAsFixed(2),
            item.quantity,
          ],
        )
        .toList();
    return base64Encode(utf8.encode(jsonEncode(rows)));
  }

  String _encodeUserBasket(List<CartItem> items) => encodeUserBasket(items);

  static String _resolveUrl(String configured, String fallback) {
    final value = configured.trim();
    return value.isNotEmpty ? value : fallback;
  }

  Future<String> _resolveUserIp() async {
    try {
      final ipDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ));
      final response = await ipDio.get<Map<String, dynamic>>(
        'https://api.ipify.org?format=json',
      );
      final ip = response.data?['ip']?.toString().trim();
      if (ip != null && ip.isNotEmpty) return ip;
    } catch (_) {}
    return '127.0.0.1';
  }
}
