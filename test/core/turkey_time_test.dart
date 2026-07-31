import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/utils/turkey_time.dart';

void main() {
  test('Turkey day rolls at 21:00 UTC (00:00 TR)', () {
    // 2026-07-25 20:59 UTC = still 25 July TR (23:59)
    final beforeMidnight = DateTime.utc(2026, 7, 25, 20, 59);
    // 2026-07-25 21:00 UTC = 26 July 00:00 TR
    final afterMidnight = DateTime.utc(2026, 7, 25, 21, 0);

    expect(TurkeyTime.turkeyDate(beforeMidnight).day, 25);
    expect(TurkeyTime.turkeyDate(afterMidnight).day, 26);
    expect(
      TurkeyTime.isSameTurkeyCalendarDay(beforeMidnight, afterMidnight),
      isFalse,
    );
  });

  test('isToday uses Turkey calendar, not device local alone', () {
    final nowUtc = DateTime.utc(2026, 7, 25, 10, 0);
    final sameDayTr = DateTime.utc(2026, 7, 25, 5, 0);
    final prevDayTr = DateTime.utc(2026, 7, 24, 20, 30); // 25 Jul 00:30 TR? 
    // 24 Jul 20:30 UTC = 24 Jul 23:30 TR → previous day vs 25 Jul 13:00 TR
    expect(TurkeyTime.isToday(sameDayTr, now: nowUtc), isTrue);
    expect(TurkeyTime.isToday(prevDayTr, now: nowUtc), isFalse);
  });
}
