abstract final class BranchHoursUtils {
  /// [openTime] / [closeTime] format: "HH:mm" (24h)
  static bool isOpenNow({
    required String openTime,
    required String closeTime,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final open = _parseMinutes(openTime);
    final close = _parseMinutes(closeTime);
    final current = now.hour * 60 + now.minute;

    if (open <= close) {
      return current >= open && current < close;
    }
    // Gece yarısını geçen saatler (ör. 22:00 - 02:00)
    return current >= open || current < close;
  }

  static int _parseMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  static String formatRange(String openTime, String closeTime) =>
      '$openTime - $closeTime';

  /// İleri tarihli teslimat: gelecekte ve şube mesai saatleri içinde olmalı.
  static bool isValidScheduledDelivery({
    required DateTime scheduledAt,
    required String openTime,
    required String closeTime,
    DateTime? now,
    Duration minLeadTime = const Duration(minutes: 30),
  }) {
    final reference = now ?? DateTime.now();
    if (!scheduledAt.isAfter(reference.add(minLeadTime))) {
      return false;
    }
    return isOpenNow(
      openTime: openTime,
      closeTime: closeTime,
      at: scheduledAt,
    );
  }
}
