import '../../shared/domain/entities/product.dart';
import '../../shared/domain/entities/product_extra.dart';
import '../../shared/domain/entities/waiter_mode_settings.dart';

double resolveWaiterPrice(
  String id,
  double catalogPrice,
  Map<String, double> overrides,
) {
  final override = overrides[id];
  if (override == null || override < 0) return catalogPrice;
  return override;
}

Product applyWaiterPriceToProduct(
  Product product,
  Map<String, double> overrides,
) {
  return product.copyWith(
    price: resolveWaiterPrice(product.id, product.price, overrides),
  );
}

ProductExtra applyWaiterPriceToCatalogExtra(
  ProductExtra extra,
  Map<String, double> overrides,
) {
  return extra.copyWith(
    price: resolveWaiterPrice(extra.id, extra.price, overrides),
  );
}

List<Product> applyWaiterPricesToProducts(
  List<Product> products,
  WaiterModeSettings? settings,
) {
  final overrides = settings?.productPrices ?? const {};
  if (overrides.isEmpty) return products;
  return products
      .map((product) => applyWaiterPriceToProduct(product, overrides))
      .toList();
}

List<ProductExtra> applyWaiterPricesToCatalogExtras(
  List<ProductExtra> extras,
  WaiterModeSettings? settings,
) {
  final overrides = settings?.catalogExtraPrices ?? const {};
  if (overrides.isEmpty) return extras;
  return extras
      .map((extra) => applyWaiterPriceToCatalogExtra(extra, overrides))
      .toList();
}

/// Yalnızca geçerli, pozitif garson fiyatlarını kayda hazırlar.
Map<String, double> normalizeWaiterPriceOverrides(Map<String, double> raw) {
  return {
    for (final entry in raw.entries)
      if (entry.value >= 0) entry.key: entry.value,
  };
}
