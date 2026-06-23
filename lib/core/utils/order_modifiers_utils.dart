import '../../shared/domain/entities/order.dart';
import '../../shared/domain/entities/product_extra.dart';
import 'cart_item_display_utils.dart';
import 'localized_text.dart';
import '../utils/waiter_order_notes.dart';
import 'waiter_preparation_tags.dart';

/// Sipariş ekleri: hazırlık tercihleri, ürün seçenekleri ve satır notları.
abstract final class OrderModifiersUtils {
  static bool hasModifiers(Order order) {
    return order.items.any(hasItemModifiers);
  }

  static bool hasItemModifiers(CartItem item) {
    return item.selectedOptions.isNotEmpty ||
        (item.note != null && item.note!.trim().isNotEmpty) ||
        item.portionKey != null;
  }

  static List<String> preparationLabels(Order order) {
    return order.preparationTags.map(WaiterPreparationTags.label).toList();
  }

  static List<String> itemModifierLines(
    CartItem item,
    List<ProductExtra> catalog,
  ) {
    final lines = <String>[];
    final extras = CartItemDisplayUtils.extraLabels(item, catalog);
    if (extras.isNotEmpty) {
      lines.add('+ ${extras.join(', ')}');
    }
    if (item.portionKey != null) {
      lines.add(localizedOrRaw(item.portionKey!));
    }
    final note = item.note?.trim();
    if (note != null && note.isNotEmpty) {
      lines.add(note);
    }
    return lines;
  }

  static String itemSummaryLine(
    CartItem item,
    List<ProductExtra> catalog,
  ) {
    final title =
        '${item.quantity}x ${CartItemDisplayUtils.productTitle(item)}';
    final modifiers = itemModifierLines(item, catalog);
    if (modifiers.isEmpty) return title;
    return '$title · ${modifiers.join(' · ')}';
  }

  static List<String> receiptModifierLines(
    Order order,
    List<ProductExtra> catalog,
  ) {
    final lines = <String>[];
    for (final item in order.items) {
      final modifiers = itemModifierLines(item, catalog);
      if (modifiers.isEmpty) continue;
      lines.add(
        '${item.quantity}x ${CartItemDisplayUtils.productTitle(item)}: '
        '${modifiers.join(' · ')}',
      );
    }
    return lines;
  }
}
