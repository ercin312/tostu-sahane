import '../../shared/domain/entities/order.dart';
import 'waiter_preparation_tags.dart';

/// Garson sipariş notu: serbest metin + hazırlık tercihleri tek alanda.
abstract final class WaiterOrderNotes {
  static String? build({
    String? textNote,
    Iterable<String> preparationTags = const [],
  }) {
    final parts = <String>[];
    final text = textNote?.trim();
    if (text != null && text.isNotEmpty) parts.add(text);
    final tags = preparationTags.toList();
    if (tags.isNotEmpty) {
      parts.add(WaiterPreparationTags.joinLabels(tags));
    }
    return parts.isEmpty ? null : parts.join('\n');
  }

  /// Sistem / kurtarma notları müşteri fişinde ve listede gösterilmez.
  static bool isInternalSystemNote(String? text) {
    final t = text?.trim().toLowerCase() ?? '';
    if (t.isEmpty) return false;
    return t.contains('otomatik kurtarma') ||
        t.contains('eski görüşme taslağı');
  }

  /// Başarısız telefon uyarısı (listede belirgin gösterilir).
  static bool isFailedCallNote(String? text) {
    final t = text?.trim().toLowerCase() ?? '';
    return t.contains('başarısız arama') ||
        t.contains('başarısız telefon') ||
        t.contains('görüşme yarıda');
  }

  /// Kayıtlı siparişte gösterilecek / fişe basılacak not metni.
  static String? display(Order order) {
    if (order.phoneFailed) {
      final text = order.orderNote?.trim();
      if (text != null && text.isNotEmpty) return text;
      return null;
    }
    final text =
        isInternalSystemNote(order.orderNote) ? null : order.orderNote;
    return build(
      textNote: text,
      preparationTags: order.preparationTags,
    );
  }

  static bool hasNote(Order order) {
    if (order.phoneFailed) {
      final text = order.orderNote?.trim();
      return (text != null && text.isNotEmpty) ||
          order.preparationTags.isNotEmpty;
    }
    final text = order.orderNote?.trim();
    if (isInternalSystemNote(text)) {
      return order.preparationTags.isNotEmpty;
    }
    return order.preparationTags.isNotEmpty ||
        (text != null && text.isNotEmpty);
  }

  /// Senkron birleştirmede en kapsamlı notu korur.
  static String? mergePreferRicher(
    String? a,
    String? b,
    String? fallback,
  ) {
    final candidates = [a, b, fallback]
        .map((n) => n?.trim())
        .whereType<String>()
        .where((n) => n.isNotEmpty)
        .toList();
    if (candidates.isEmpty) return fallback;
    candidates.sort((x, y) => y.length.compareTo(x.length));
    return candidates.first;
  }
}
