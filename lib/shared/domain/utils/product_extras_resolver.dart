import '../entities/product.dart';
import '../entities/product_extra.dart';

abstract final class ProductExtrasResolver {
  static List<String> resolveExtraIds(Product product) {
    if (product.extraIds.isNotEmpty) return product.extraIds;
    if (product.extras.isNotEmpty) {
      return product.extras.map((extra) => extra.id).toList();
    }
    return const [];
  }

  static Product withResolvedExtras(
    Product product,
    List<ProductExtra> catalog, {
    List<String> fallbackExtraIds = const [],
  }) {
    final catalogById = {for (final extra in catalog) extra.id: extra};
    final ids = resolveExtraIds(product);
    final effectiveIds = ids.isNotEmpty ? ids : fallbackExtraIds;

    final resolved = <ProductExtra>[
      for (final id in effectiveIds)
        if (catalogById[id] != null) catalogById[id]!,
    ];

    return product.copyWith(
      extras: resolved,
      extraIds: effectiveIds,
    );
  }

  static List<Product> resolveAll(
    List<Product> products,
    List<ProductExtra> catalog,
  ) {
    return products
        .map((product) => withResolvedExtras(product, catalog))
        .toList();
  }
}
