import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/display_order_utils.dart';
import '../../../../core/utils/waiter_prices.dart';
import '../../../../shared/domain/entities/product.dart';
import '../../../../shared/domain/entities/product_extra.dart';
import '../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../../customer/home/presentation/providers/branch_provider.dart';

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

final waiterCatalogExtrasProvider = Provider<List<ProductExtra>>((ref) {
  final extras = ref.watch(catalogExtrasProvider).value ?? [];
  final settings = ref.watch(waiterModeSettingsProvider).valueOrNull;
  final priced = applyWaiterPricesToCatalogExtras(extras, settings);
  return sortByDisplayOrder(
    items: priced,
    displayOrder: settings?.catalogExtraDisplayOrder ?? const [],
    idFor: (e) => e.id,
    tieBreaker: (a, b) => a.name.compareTo(b.name),
  );
});
