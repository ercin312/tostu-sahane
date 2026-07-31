import 'package:easy_localization/easy_localization.dart';

import '../localization/locale_keys.dart';
import '../../shared/domain/entities/auth.dart';

/// SMS OTP gönderim/doğrulama hata kodlarını kullanıcı metnine çevirir.
String otpSendErrorMessage(Object error) {
  final key = error is AuthCredentialsException
      ? error.messageKey
      : error is StateError
          ? error.message
          : null;
  return switch (key) {
    'sms_not_configured' => LocaleKeys.authOtpSmsNotConfigured.tr(),
    'sms_header_invalid' => LocaleKeys.authOtpSmsHeaderInvalid.tr(),
    'sms_auth_failed' => LocaleKeys.authOtpSmsAuthFailed.tr(),
    'otp_rate_limited' => LocaleKeys.authOtpRateLimited.tr(),
    'invalid_phone' => LocaleKeys.authInvalidPhone.tr(),
    'phone_already_registered' => LocaleKeys.authPhoneAlreadyRegistered.tr(),
    'sms_send_failed' => LocaleKeys.authOtpSendFailed.tr(),
    _ => LocaleKeys.authOtpSendFailed.tr(),
  };
}

String otpVerifyErrorMessage(Object error) {
  final key = error is AuthCredentialsException
      ? error.messageKey
      : error is StateError
          ? error.message
          : null;
  return switch (key) {
    'otp_expired' => LocaleKeys.authOtpExpired.tr(),
    'otp_locked' => LocaleKeys.authOtpLocked.tr(),
    'invalid_otp' => LocaleKeys.authInvalidOtp.tr(),
    _ => LocaleKeys.authInvalidOtp.tr(),
  };
}
