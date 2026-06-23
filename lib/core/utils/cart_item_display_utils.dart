import '../../shared/domain/entities/order.dart';
import '../../shared/domain/entities/product_extra.dart';
import 'localized_text.dart';

abstract final class CartItemDisplayUtils {
  static String extraLabel(String extraId, List<ProductExtra> catalog) {
    for (final extra in catalog) {
      if (extra.id == extraId) {
        return localizedOrRaw(extra.name);
      }
    }
    return localizedOrRaw(extraId);
  }

  static List<String> extraLabels(
    CartItem item,
    List<ProductExtra> catalog,
  ) {
    return [
      for (final id in item.selectedOptions) extraLabel(id, catalog),
    ];
  }

  static String productTitle(CartItem item) {
    return localizedOrRaw(item.productNameKey);
  }

  static String quantityLine(
    CartItem item,
    List<ProductExtra> catalog, {
    bool includePortion = true,
  }) {
    final buffer = StringBuffer('${item.quantity}x ${productTitle(item)}');
    final extras = extraLabels(item, catalog);
    if (extras.isNotEmpty) {
      buffer.write(' (+ ${extras.join(', ')})');
    }
    if (includePortion && item.portionKey != null) {
      buffer.write(' · ${localizedOrRaw(item.portionKey!)}');
    }
    return buffer.toString();
  }

  static String receiptProductLine(
    CartItem item,
    List<ProductExtra> catalog,
  ) {
    final title = productTitle(item).toUpperCase();
    final extras = extraLabels(item, catalog);
    if (extras.isEmpty) return title;
    return '$title\n+ ${extras.join(', ')}';
  }
}
