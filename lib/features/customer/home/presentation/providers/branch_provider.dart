import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../../core/services/location_service.dart';
import '../../../../../core/utils/delivery_zone_utils.dart';
import '../../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../../shared/data/mock/mock_data.dart';
import '../../../../../shared/domain/entities/user.dart';
import '../../../../../shared/domain/entities/branch.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/product_extra.dart';
import '../../../../../shared/presentation/providers/repository_providers.dart';
import '../../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';

class BranchNotifier extends AsyncNotifier<Branch> {
  @override
  Future<Branch> build() async {
    try {
      final branches = await ref.read(branchRepositoryProvider).getBranches();
      if (branches.isEmpty) {
        return MockData.branches.first;
      }

      final position = await LocationService.getCurrentPosition();
      if (position != null) {
        final nearest = _nearestDeliveringBranch(branches, position);
        if (nearest != null) return nearest;
      }

      return branches.first;
    } catch (_) {
      return MockData.branches.first;
    }
  }

  Branch? _nearestDeliveringBranch(List<Branch> branches, Position position) {
    return DeliveryZoneUtils.nearestDeliveringBranch(
      branches,
      position.latitude,
      position.longitude,
    );
  }

  Branch _nearestBranch(List<Branch> branches, Position position) {
    Branch nearest = branches.first;
    var minDistance = double.infinity;

    for (final branch in branches) {
      final distance = LocationService.distanceKm(
        position.latitude,
        position.longitude,
        branch.latitude,
        branch.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        nearest = branch.copyWith(
          distanceKm: double.parse(distance.toStringAsFixed(1)),
        );
      }
    }
    return nearest;
  }

  Future<Branch?> findNearestDeliveringBranch() async {
    try {
      final branches = await ref.read(branchRepositoryProvider).getBranches();
      final position = await LocationService.getCurrentPosition();
      if (position == null) return null;
      return _nearestDeliveringBranch(branches, position);
    } catch (_) {
      return null;
    }
  }

  Future<void> selectBranch(Branch branch) async {
    state = AsyncData(branch);
  }

  Future<Branch?> selectNearestFromLocation() async {
    try {
      final branches = await ref.read(branchRepositoryProvider).getBranches();
      if (branches.isEmpty) return null;

      final position = await LocationService.getCurrentPosition();
      if (position == null) return null;

      final nearest = _nearestDeliveringBranch(branches, position);
      if (nearest != null) {
        state = AsyncData(nearest);
        return nearest;
      }

      final fallback = _nearestBranch(branches, position);
      state = AsyncData(fallback);
      return null;
    } catch (_) {
      return null;
    }
  }

  bool isAddressDeliverable(Branch branch, double? lat, double? lng) {
    if (lat == null || lng == null) return true;
    return DeliveryZoneUtils.isDeliverable(branch, lat, lng);
  }
}

final branchProvider = AsyncNotifierProvider<BranchNotifier, Branch>(
  BranchNotifier.new,
);

final branchesProvider = FutureProvider<List<Branch>>((ref) async {
  try {
    return await ref.read(branchRepositoryProvider).getBranches();
  } catch (_) {
    return MockData.branches;
  }
});

final managedBranchProvider = FutureProvider<Branch?>((ref) async {
  final auth = ref.watch(authProvider);
  List<Branch> branches;
  try {
    branches = await ref.read(branchRepositoryProvider).getBranches();
  } catch (_) {
    branches = MockData.branches;
  }
  if (branches.isEmpty) return null;

    if (auth?.user.role == UserRole.branchManager ||
      auth?.user.role == UserRole.branchStaff ||
      auth?.user.role == UserRole.waiter ||
      auth?.user.role == UserRole.kitchenStaff) {
    final branchId = auth!.user.branchId ?? branches.first.id;
    return branches.firstWhere(
      (b) => b.id == branchId,
      orElse: () => branches.first,
    );
  }

  return ref.watch(branchProvider).value ?? branches.first;
});

final deliverableBranchesProvider = Provider<List<Branch>>((ref) {
  return ref.watch(branchesProvider).value ?? MockData.branches;
});

class ProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    ref.listen(branchProvider, (previous, next) {
      final prevId = previous?.value?.id;
      final nextId = next.value?.id;
      if (prevId != nextId && next.hasValue) {
        ref.invalidateSelf();
      }
    });

    final branchId = ref.read(branchProvider).value?.id;
    try {
      return await ref
          .read(productRepositoryProvider)
          .getProducts(branchId: branchId);
    } catch (_) {
      return MockData.products;
    }
  }

  Future<void> toggleAvailability(String productId) async {
    final current = state.value ?? [];
    final product = current.firstWhere((p) => p.id == productId);
    final updated = await ref
        .read(productRepositoryProvider)
        .toggleAvailability(productId, !product.isAvailable);
    state = AsyncData([
      for (final p in current) if (p.id == productId) updated else p,
    ]);
  }
}

final productsProvider = AsyncNotifierProvider<ProductsNotifier, List<Product>>(
  ProductsNotifier.new,
);

final opsBranchProductsProvider = FutureProvider<List<Product>>((ref) async {
  final branch = await ref.watch(managedBranchProvider.future);
  if (branch == null) return [];
  try {
    return await ref
        .read(productRepositoryProvider)
        .getProducts(branchId: branch.id);
  } catch (_) {
    return MockData.products;
  }
});

final catalogExtrasProvider = FutureProvider<List<ProductExtra>>((ref) async {
  try {
    return await ref.read(productRepositoryProvider).getCatalogExtras();
  } catch (_) {
    return MockData.catalogExtras;
  }
});

final selectedCategoryProvider =
    StateProvider<ProductCategory>((ref) => ProductCategory.all);

final productSearchQueryProvider = StateProvider<String>((ref) => '');

final customerVisibleCategoriesProvider = Provider<List<ProductCategory>>((ref) {
  final settings =
      ref.watch(waiterModeSettingsProvider).valueOrNull;
  final sahandaEnabled = settings?.customerSahandaEnabled ?? true;
  return ProductCategory.values.where((category) {
    if (category == ProductCategory.sahanda && !sahandaEnabled) {
      return false;
    }
    return true;
  }).toList();
});

final filteredProductsProvider = Provider<List<Product>>((ref) {
  final productsAsync = ref.watch(productsProvider);
  final products = productsAsync.value ?? [];
  final category = ref.watch(selectedCategoryProvider);
  final query = ref.watch(productSearchQueryProvider).trim().toLowerCase();
  final sahandaEnabled =
      ref.watch(waiterModeSettingsProvider).valueOrNull?.customerSahandaEnabled ??
          true;

  var filtered = category == ProductCategory.all
      ? products
      : products.where((p) => p.category == category);

  if (!sahandaEnabled) {
    filtered = filtered.where((p) => p.category != ProductCategory.sahanda);
  }

  if (query.isNotEmpty) {
    filtered = filtered.where((p) {
      final label = p.nameKey.contains('_')
          ? p.nameKey.tr().toLowerCase()
          : p.nameKey.toLowerCase();
      return label.contains(query);
    });
  }

  return filtered.toList();
});

final recommendedProductsProvider = Provider<List<Product>>((ref) {
  final products = ref.watch(productsProvider).value ?? [];
  return products
      .where((p) => p.isRecommended && p.isAvailable)
      .take(8)
      .toList();
});
