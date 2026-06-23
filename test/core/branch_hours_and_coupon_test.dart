import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/utils/branch_hours_utils.dart';
import 'package:tostu_sahane/shared/domain/entities/coupon.dart';

void main() {
  group('BranchHoursUtils', () {
    test('is open during business hours', () {
      expect(
        BranchHoursUtils.isOpenNow(
          openTime: '09:00',
          closeTime: '23:00',
          at: DateTime(2026, 6, 18, 14, 30),
        ),
        isTrue,
      );
    });

    test('is closed before opening', () {
      expect(
        BranchHoursUtils.isOpenNow(
          openTime: '09:00',
          closeTime: '23:00',
          at: DateTime(2026, 6, 18, 7, 0),
        ),
        isFalse,
      );
    });

    test('valid scheduled delivery within hours and lead time', () {
      final now = DateTime(2026, 6, 18, 20, 0);
      expect(
        BranchHoursUtils.isValidScheduledDelivery(
          scheduledAt: DateTime(2026, 6, 19, 12, 0),
          openTime: '09:00',
          closeTime: '23:00',
          now: now,
        ),
        isTrue,
      );
    });

    test('rejects scheduled delivery outside hours', () {
      final now = DateTime(2026, 6, 18, 20, 0);
      expect(
        BranchHoursUtils.isValidScheduledDelivery(
          scheduledAt: DateTime(2026, 6, 19, 8, 0),
          openTime: '09:00',
          closeTime: '23:00',
          now: now,
        ),
        isFalse,
      );
    });

    test('allows scheduled delivery while branch is closed now', () {
      final now = DateTime(2026, 6, 18, 7, 0);
      expect(
        BranchHoursUtils.isOpenNow(
          openTime: '09:00',
          closeTime: '23:00',
          at: now,
        ),
        isFalse,
      );
      expect(
        BranchHoursUtils.isValidScheduledDelivery(
          scheduledAt: DateTime(2026, 6, 18, 12, 0),
          openTime: '09:00',
          closeTime: '23:00',
          now: now,
        ),
        isTrue,
      );
    });
  });

  group('Coupon', () {
    test('percent discount applies correctly', () {
      const coupon = Coupon(
        code: 'SAHANE10',
        type: CouponType.percent,
        value: 10,
        minOrderAmount: 50,
      );
      expect(coupon.discountFor(100), 10);
    });

    test('fixed discount respects subtotal cap', () {
      const coupon = Coupon(
        code: 'TOS20',
        type: CouponType.fixed,
        value: 20,
        minOrderAmount: 100,
      );
      expect(coupon.discountFor(150), 20);
      expect(coupon.discountFor(80), 0);
    });
  });
}
