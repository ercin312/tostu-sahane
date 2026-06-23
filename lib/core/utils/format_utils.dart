import 'package:intl/intl.dart';

abstract final class FormatUtils {
  static String currency(double amount, {String? locale}) {
    final formatter = NumberFormat.currency(
      locale: locale ?? 'tr_TR',
      symbol: '₺',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }
}
