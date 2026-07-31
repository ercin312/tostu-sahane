import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/auth/sms_otp_client.dart';

void main() {
  group('SmsOtpClient.normalizePhone', () {
    test('normalizes TR mobiles', () {
      expect(SmsOtpClient.normalizePhone('05551234567'), '905551234567');
      expect(SmsOtpClient.normalizePhone('5551234567'), '905551234567');
    });

    test('strips formatting', () {
      expect(
        SmsOtpClient.normalizePhone('+90 555 123 45 67'),
        '905551234567',
      );
    });
  });
}
