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

  /// Kayıtlı siparişte gösterilecek / fişe basılacak not metni.
  static String? display(Order order) {
    return build(
      textNote: order.orderNote,
      preparationTags: order.preparationTags,
    );
  }

  static bool hasNote(Order order) {
    final text = order.orderNote?.trim();
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
