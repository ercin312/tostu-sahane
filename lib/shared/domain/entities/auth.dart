enum AuthOtpChannel { phone, email }

class AuthCredentialsException implements Exception {
  const AuthCredentialsException(this.messageKey);
  final String messageKey;
}
