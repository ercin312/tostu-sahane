import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/order.dart';
import '../../../../shared/domain/entities/product.dart';
import '../../../../shared/domain/entities/product_extra.dart';

class WaiterCartItem {
  const WaiterCartItem({
    this.product,
    this.catalogExtra,
    required this.quantity,
    this.selectedExtraIds = const [],
    this.note,
  }) : assert(product != null || catalogExtra != null);

  final Product? product;
  final ProductExtra? catalogExtra;
  final int quantity;
  final List<String> selectedExtraIds;
  final String? note;

  String get lineKey {
    if (product != null) {
      final extras = selectedExtraIds.join(',');
      return '${product!.id}|$extras';
    }
    return 'extra_${catalogExtra!.id}';
  }

  String get displayNameKey =>
      product?.nameKey ?? catalogExtra!.name;

  double unitPrice(Product productWithExtras) {
    if (catalogExtra != null) return catalogExtra!.price;
    var price = product!.price;
    for (final extra in productWithExtras.extras) {
      if (selectedExtraIds.contains(extra.id)) price += extra.price;
    }
    return price;
  }

  double lineTotal(Product productWithExtras) =>
      unitPrice(productWithExtras) * quantity;

  CartItem toCartItem([Product? productWithExtras]) {
    final id = '${lineKey}_${DateTime.now().microsecondsSinceEpoch}';
    if (catalogExtra != null) {
      return CartItem(
        id: id,
        productId: 'extra_${catalogExtra!.id}',
        productNameKey: catalogExtra!.name,
        unitPrice: catalogExtra!.price,
        quantity: quantity,
        note: note,
      );
    }
    final resolved = productWithExtras ?? product!;
    return CartItem(
      id: id,
      productId: product!.id,
      productNameKey: product!.nameKey,
      unitPrice: unitPrice(resolved),
      quantity: quantity,
      selectedOptions: List.of(selectedExtraIds),
      note: note,
    );
  }
}

class WaiterCartNotifier extends Notifier<List<WaiterCartItem>> {
  @override
  List<WaiterCartItem> build() => const [];

  void clear() => state = const [];

  void decrementProduct(Product product) {
    final matching =
        state.where((item) => item.product?.id == product.id).toList();
    if (matching.isEmpty) return;
    final line = matching.last;
    setQuantity(line.lineKey, line.quantity - 1);
  }

  void addProduct(
    Product product, {
    List<String> extraIds = const [],
  }) {
    final key = '${product.id}|${extraIds.join(',')}';
    final index = state.indexWhere((item) => item.lineKey == key);
    if (index >= 0) {
      final updated = [...state];
      final current = updated[index];
      updated[index] = WaiterCartItem(
        product: current.product,
        catalogExtra: current.catalogExtra,
        quantity: current.quantity + 1,
        selectedExtraIds: current.selectedExtraIds,
        note: current.note,
      );
      state = updated;
      return;
    }
    state = [
      ...state,
      WaiterCartItem(
        product: product,
        quantity: 1,
        selectedExtraIds: extraIds,
      ),
    ];
  }

  void addCatalogExtra(ProductExtra extra) {
    final index = state.indexWhere(
      (item) => item.catalogExtra?.id == extra.id,
    );
    if (index >= 0) {
      final updated = [...state];
      final current = updated[index];
      updated[index] = WaiterCartItem(
        catalogExtra: current.catalogExtra,
        quantity: current.quantity + 1,
      );
      state = updated;
      return;
    }
    state = [
      ...state,
      WaiterCartItem(catalogExtra: extra, quantity: 1),
    ];
  }

  void setQuantity(String lineKey, int quantity) {
    if (quantity <= 0) {
      state = state.where((item) => item.lineKey != lineKey).toList();
      return;
    }
    state = [
      for (final item in state)
        if (item.lineKey == lineKey)
          WaiterCartItem(
            product: item.product,
            catalogExtra: item.catalogExtra,
            quantity: quantity,
            selectedExtraIds: item.selectedExtraIds,
            note: item.note,
          )
        else
          item,
    ];
  }

  double total(List<Product> products) {
    return state.fold(0, (sum, item) {
      if (item.catalogExtra != null) {
        return sum + item.catalogExtra!.price * item.quantity;
      }
      final product = products.firstWhere(
        (p) => p.id == item.product!.id,
        orElse: () => item.product!,
      );
      return sum + item.lineTotal(product);
    });
  }

  List<CartItem> toCartItems(List<Product> products) {
    return state.map((item) {
      if (item.catalogExtra != null) return item.toCartItem();
      final product = products.firstWhere(
        (p) => p.id == item.product!.id,
        orElse: () => item.product!,
      );
      return item.toCartItem(product);
    }).toList();
  }
}

final waiterCartProvider =
    NotifierProvider<WaiterCartNotifier, List<WaiterCartItem>>(
  WaiterCartNotifier.new,
);
