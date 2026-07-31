/// Türkiye saati (UTC+3, DST yok — 2016'dan beri sabit).
/// Günlük ciro / sipariş sayacı gece 00:00 TR'de sıfırlanır.
abstract final class TurkeyTime {
  static const Duration offsetFromUtc = Duration(hours: 3);

  /// Anlık UTC → Türkiye duvar saati bileşenleri (DateTime.now() yerel değil).
  static DateTime wallClock([DateTime? instant]) {
    final utc = (instant ?? DateTime.now()).toUtc();
    return utc.add(offsetFromUtc);
  }

  /// Verilen anın Türkiye takvim günü (yıl/ay/gün) UTC+3.
  static ({int year, int month, int day}) turkeyDate([DateTime? instant]) {
    final wall = wallClock(instant);
    return (year: wall.year, month: wall.month, day: wall.day);
  }

  static bool isSameTurkeyCalendarDay(DateTime a, DateTime b) {
    final da = turkeyDate(a);
    final db = turkeyDate(b);
    return da.year == db.year && da.month == db.month && da.day == db.day;
  }

  /// Sipariş Türkiye’de “bugün” mü oluşturuldu?
  static bool isToday(DateTime createdAt, {DateTime? now}) {
    return isSameTurkeyCalendarDay(createdAt, now ?? DateTime.now());
  }
}
