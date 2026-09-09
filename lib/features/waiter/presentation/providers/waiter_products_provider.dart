import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/display_order_utils.dart';
import '../../../../core/utils/waiter_pos_catalog_utils.dart';
import '../../../../core/utils/waiter_prices.dart';
import '../../../../shared/domain/entities/product.dart';
import '../../../../shared/domain/entities/product_extra.dart';
import '../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../../customer/home/presentation/providers/branch_provider.dart';
import '../../domain/waiter_pos_catalog.dart';

final waiterBranchProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(opsBranchProductsProvider).value ?? [];
  final settings = ref.watch(waiterModeSettingsProvider).valueOrNull;
  final priced = applyWaiterPricesToProducts(products, settings);
  return sortByDisplayOrder(
    items: priced,
    displayOrder: settings?.productDisplayOrder ?? const [],
    idFor: (p) => p.id,
    tieBreaker: (a, b) => a.nameKey.compareTo(b.nameKey),
  );
});

/// Garson POS ızgarası: kasa/admin ile aynı canlı katalog (+ override).
final waiterPosSectionProductsProvider =
    Provider.family<List<Product>, WaiterPosSection>((ref, section) {
  final products = ref.watch(waiterBranchProductsProvider);
  return waiterPosProductsForSection(products, section);
});

final waiterCatalogExtrasProvider = Provider<List<ProductExtra>>((ref) {
  final extras = ref.watch(catalogExtrasProvider).value ?? [];
  final settings = ref.watch(waiterModeSettingsProvider).valueOrNull;
  final priced = applyWaiterPricesToCatalogExtras(extras, settings)
      .where((extra) => !extra.isToastIngredient)
      .toList();
  return sortByDisplayOrder(
    items: priced,
    displayOrder: settings?.catalogExtraDisplayOrder ?? const [],
    idFor: (e) => e.id,
    tieBreaker: (a, b) => a.name.compareTo(b.name),
  );
});
