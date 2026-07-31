import 'package:intl/intl.dart';

import 'turkey_time.dart';

abstract final class FormatUtils {
  static String currency(double amount, {String? locale}) {
    final formatter = NumberFormat.currency(
      locale: locale ?? 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Sipariş tarih/saati — her zaman Türkiye duvar saati (UTC+3).
  static String dateTimeTr(DateTime instant, {String pattern = 'dd.MM.yyyy HH:mm'}) {
    final wall = TurkeyTime.wallClock(instant);
    // wallClock UTC anına +3 ekler; DateFormat yerel alanları kullanır.
    return DateFormat(pattern).format(wall);
  }

  static String timeTr(DateTime instant) => dateTimeTr(instant, pattern: 'HH:mm');
}
