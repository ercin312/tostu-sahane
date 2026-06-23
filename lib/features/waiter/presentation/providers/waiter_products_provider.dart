import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/waiter_prices.dart';
import '../../../../shared/domain/entities/product.dart';
import '../../../../shared/domain/entities/product_extra.dart';
import '../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../../customer/home/presentation/providers/branch_provider.dart';

final waiterBranchProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(opsBranchProductsProvider).value ?? [];
  final settings = ref.watch(waiterModeSettingsProvider).valueOrNull;
  return applyWaiterPricesToProducts(products, settings);
});

final waiterCatalogExtrasProvider = Provider<List<ProductExtra>>((ref) {
  final extras = ref.watch(catalogExtrasProvider).value ?? [];
  final settings = ref.watch(waiterModeSettingsProvider).valueOrNull;
  return applyWaiterPricesToCatalogExtras(extras, settings);
});
