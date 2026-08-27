import '../../shared/domain/entities/order.dart';
import '../../shared/domain/entities/product.dart';

/// Mutfak fişi / KDS: içecek ve katalog ekstraları (extra_*) mutfağa gitmez.
bool isKitchenCartItem(
  CartItem item, {
  List<Product> catalog = const [],
}) {
  final id = item.productId.trim();
  if (id.startsWith('extra_')) return false;
  final category = item.productCategory?.trim().toLowerCase();
  if (category == ProductCategory.drink.name || category == 'drink') {
    return false;
  }
  if (category != null && category.isNotEmpty) return true;
  for (final product in catalog) {
    if (product.id == id) {
      return product.category != ProductCategory.drink;
    }
  }
  return true;
}

List<CartItem> kitchenCartItems(
  Order order, {
  List<Product> catalog = const [],
}) =>
    order.items
        .where((item) => isKitchenCartItem(item, catalog: catalog))
        .toList(growable: false);

bool orderHasKitchenItems(
  Order order, {
  List<Product> catalog = const [],
}) =>
    order.items.any((item) => isKitchenCartItem(item, catalog: catalog));
