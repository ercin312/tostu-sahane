import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../shared/domain/entities/waiter_mode_settings.dart';

class PosPaymentResult {
  const PosPaymentResult({
    required this.success,
    required this.transactionId,
    this.authCode,
    this.rawResponse,
  });

  final bool success;
  final String transactionId;
  final String? authCode;
  final Map<String, dynamic>? rawResponse;
}

class PosTerminalException implements Exception {
  const PosTerminalException(this.messageKey, {this.detail});

  final String messageKey;
  final String? detail;

  @override
  String toString() => messageKey;
}

/// Ethernet üzerinden bağlı Pavo / REST POS cihazına tutar gönderir.
abstract final class PosTerminalService {
  static const _timeout = Duration(seconds: 120);

  static Future<PosPaymentResult> chargeCard({
    required double amount,
    required String reference,
    required WaiterModeSettings settings,
    Dio? dio,
  }) async {
    if (!settings.posEnabled) {
      throw const PosTerminalException('waiter_pos_not_configured');
    }
    final baseUrl = settings.posBaseUrl;
    if (baseUrl.isEmpty) {
      throw const PosTerminalException('waiter_pos_not_configured');
    }

    final client = dio ??
        Dio(
          BaseOptions(
            connectTimeout: _timeout,
            receiveTimeout: _timeout,
            sendTimeout: _timeout,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );

    final path = settings.posSalePath.startsWith('/')
        ? settings.posSalePath
        : '/${settings.posSalePath}';
    final url = '$baseUrl$path';

    final body = <String, dynamic>{
      'Amount': double.parse(amount.toStringAsFixed(2)),
      'amount': double.parse(amount.toStringAsFixed(2)),
      'Currency': 'TRY',
      'currency': 'TRY',
      'PaymentType': 'CreditCard',
      'paymentType': 'CreditCard',
      'SerialNumber': settings.posSerialNumber,
      'serialNumber': settings.posSerialNumber,
      'Reference': reference,
      'reference': reference,
      'Description': reference,
      'description': reference,
    };

    try {
      debugPrint('POS charge: POST $url amount=$amount ref=$reference');
      final response = await client.post<Map<String, dynamic>>(
        url,
        data: body,
      );
      return _parseResponse(response.data, reference);
    } on DioException catch (e) {
      debugPrint('POS charge failed: ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw PosTerminalException(
          'waiter_pos_timeout',
          detail: e.message,
        );
      }
      if (e.type == DioExceptionType.connectionError) {
        throw PosTerminalException(
          'waiter_pos_connection_error',
          detail: e.message,
        );
      }
      throw PosTerminalException(
        'waiter_pos_failed',
        detail: e.response?.data?.toString() ?? e.message,
      );
    } catch (e) {
      if (e is PosTerminalException) rethrow;
      throw PosTerminalException('waiter_pos_failed', detail: '$e');
    }
  }

  static PosPaymentResult _parseResponse(
    Map<String, dynamic>? data,
    String reference,
  ) {
    if (data == null) {
      throw const PosTerminalException('waiter_pos_failed');
    }

    final status = _readString(data, const [
      'status',
      'Status',
      'result',
      'Result',
      'success',
      'Success',
    ]);
    final errorCode = _readString(data, const [
      'errorCode',
      'ErrorCode',
      'error_code',
    ]);
    final errorMessage = _readString(data, const [
      'errorMessage',
      'ErrorMessage',
      'message',
      'Message',
    ]);

    final successFlag = data['success'] == true || data['Success'] == true;
    final statusOk = status != null &&
        const {'success', 'ok', 'approved', 'completed', 'true'}
            .contains(status.toLowerCase());
    final hasError = errorCode != null &&
        errorCode.isNotEmpty &&
        errorCode != '0' &&
        errorCode.toLowerCase() != 'null';

    if (!successFlag && !statusOk && hasError) {
      throw PosTerminalException(
        'waiter_pos_declined',
        detail: errorMessage ?? errorCode,
      );
    }

    final txnId = _readString(data, const [
          'paymentId',
          'PaymentId',
          'transactionId',
          'TransactionId',
          'transactionReferenceId',
          'TransactionReferenceId',
          'authCode',
          'AuthCode',
          'hostReference',
          'HostReference',
        ]) ??
        reference;

    return PosPaymentResult(
      success: true,
      transactionId: txnId,
      authCode: _readString(data, const ['authCode', 'AuthCode']),
      rawResponse: data,
    );
  }

  static String? _readString(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = '$value'.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }
}
