import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../config/app_config.dart';

/// Cloud Functions: SMS OTP (kayıt) + telefon/şifre giriş.
abstract final class SmsOtpClient {
  static Dio? _dio;

  static Dio get _client {
    return _dio ??= Dio(
      BaseOptions(
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        headers: const {'Content-Type': 'application/json'},
      ),
    );
  }

  static String get _projectId =>
      DefaultFirebaseOptions.currentPlatform.projectId;

  static String get _region => 'us-central1';

  static String _url(String name) =>
      'https://$_region-$_projectId.cloudfunctions.net/$name';

  static String normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      digits = '90${digits.substring(1)}';
    }
    if (digits.length == 10 && digits.startsWith('5')) {
      digits = '90$digits';
    }
    return digits;
  }

  static Future<void> sendOtp(String phone) async {
    final normalized = normalizePhone(phone);
    try {
      await _client.post<Map<String, dynamic>>(
        _url('sendSmsOtp'),
        data: {
          'phone': normalized,
          'for_registration': true,
        },
      );
    } on DioException catch (e) {
      final code = e.response?.data is Map
          ? (e.response!.data as Map)['error']?.toString()
          : null;
      debugPrint('SMS OTP send failed: $code ${e.message}');
      throw StateError(code ?? 'otp_send_failed');
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String code,
    required String password,
    String? name,
  }) async {
    final normalized = normalizePhone(phone);
    try {
      final response = await _client.post<Map<String, dynamic>>(
        _url('verifySmsOtp'),
        data: {
          'phone': normalized,
          'code': code.trim(),
          'password': password,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        },
      );
      final data = response.data ?? const {};
      final user = data['user'];
      if (user is! Map) {
        throw StateError('invalid_otp');
      }
      return Map<String, dynamic>.from(user);
    } on DioException catch (e) {
      final codeErr = e.response?.data is Map
          ? (e.response!.data as Map)['error']?.toString()
          : null;
      debugPrint('SMS OTP verify failed: $codeErr ${e.message}');
      throw StateError(codeErr ?? 'invalid_otp');
    }
  }

  static Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    final normalized = normalizePhone(phone);
    try {
      final response = await _client.post<Map<String, dynamic>>(
        _url('loginCustomer'),
        data: {
          'phone': normalized,
          'password': password,
        },
      );
      final data = response.data ?? const {};
      final user = data['user'];
      if (user is! Map) {
        throw StateError('invalid_credentials');
      }
      return Map<String, dynamic>.from(user);
    } on DioException catch (e) {
      final codeErr = e.response?.data is Map
          ? (e.response!.data as Map)['error']?.toString()
          : null;
      debugPrint('Customer login failed: $codeErr ${e.message}');
      throw StateError(codeErr ?? 'invalid_credentials');
    }
  }
}
