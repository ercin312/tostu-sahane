import '../../features/waiter/domain/waiter_pos_catalog.dart';
import '../../shared/domain/entities/product.dart';

/// Garson POS bölümü → canlı katalog kategorisi.
ProductCategory waiterPosCategoryFor(WaiterPosSection section) =>
    switch (section) {
      WaiterPosSection.tostlar => ProductCategory.tost,
      WaiterPosSection.sahan => ProductCategory.sahanda,
      WaiterPosSection.icecekler => ProductCategory.drink,
      WaiterPosSection.yanUrunler => ProductCategory.snack,
    };

/// Kasa/admin ile aynı ürün listesinden garson POS ızgarası.
/// Yalnızca satılabilir (`isAvailable`) ürünler; combo → tostlar.
List<Product> waiterPosProductsForSection(
  List<Product> products,
  WaiterPosSection section,
) {
  return products.where((product) {
    if (!product.isAvailable) return false;
    if (section == WaiterPosSection.tostlar) {
      return product.category == ProductCategory.tost ||
          product.category == ProductCategory.combo ||
          product.isCombo;
    }
    return product.category == waiterPosCategoryFor(section);
  }).toList();
}
