import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/models/api_models.dart';
import '../../../../shared/domain/entities/branch.dart';
import '../../../../shared/domain/entities/product.dart';
import '../../../../shared/domain/entities/product_extra.dart';
import '../../../../shared/domain/entities/product_combo_item.dart';
import '../../../../shared/data/mock/mock_data.dart';
import '../../../../shared/presentation/providers/repository_providers.dart';
import '../../../customer/home/presentation/providers/branch_provider.dart';

class AdminBranchesNotifier extends AsyncNotifier<List<Branch>> {
  @override
  Future<List<Branch>> build() {
    return ref.read(adminRepositoryProvider).getBranches();
  }

  Future<void> createBranch({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String openTime = '09:00',
    String closeTime = '23:00',
  }) async {
    final branch = Branch(
      id: 'branch_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      openTime: openTime,
      closeTime: closeTime,
    );
    final created =
        await ref.read(adminRepositoryProvider).createBranch(branch);
    state = AsyncData([...(state.value ?? []), created]);
    ref.invalidate(branchProvider);
    ref.invalidate(branchesProvider);
    ref.invalidate(adminReportsProvider);
  }

  Future<void> updateBranch(Branch branch) async {
    final updated =
        await ref.read(adminRepositoryProvider).updateBranch(branch);
    state = AsyncData([
      for (final b in state.value ?? []) if (b.id == updated.id) updated else b,
    ]);
    ref.invalidate(branchProvider);
    ref.invalidate(branchesProvider);
  }

  Future<void> deleteBranch(String branchId) async {
    await ref.read(adminRepositoryProvider).deleteBranch(branchId);
    state = AsyncData(
      (state.value ?? []).where((b) => b.id != branchId).toList(),
    );
    ref.invalidate(branchProvider);
    ref.invalidate(branchesProvider);
    ref.invalidate(adminReportsProvider);
  }
}

final adminBranchesProvider =
    AsyncNotifierProvider<AdminBranchesNotifier, List<Branch>>(
  AdminBranchesNotifier.new,
);

class AdminProductsNotifier extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() {
    return ref.read(productRepositoryProvider).getProducts();
  }

  Future<void> createProduct({
    required String name,
    required String description,
    required double price,
    required ProductCategory category,
    String? imageUrl,
    List<String> extraIds = const [],
    bool isCombo = false,
    List<ProductComboItem> comboItems = const [],
    bool isRecommended = false,
  }) async {
    final product = Product(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      nameKey: name,
      descriptionKey: description,
      price: price,
      category: category,
      imageUrl: imageUrl,
      extraIds: extraIds,
      isCombo: isCombo,
      comboItems: comboItems,
      isRecommended: isRecommended,
    );
    final created =
        await ref.read(productRepositoryProvider).createProduct(product);
    state = AsyncData([...(state.value ?? []), created]);
    Future.microtask(() => ref.invalidate(productsProvider));
  }

  Future<void> updateProduct(Product product) async {
    final updated =
        await ref.read(productRepositoryProvider).updateProduct(product);
    state = AsyncData([
      for (final p in state.value ?? []) if (p.id == updated.id) updated else p,
    ]);
    Future.microtask(() => ref.invalidate(productsProvider));
  }

  Future<void> deleteProduct(String productId) async {
    await ref.read(productRepositoryProvider).deleteProduct(productId);
    state = AsyncData(
      (state.value ?? []).where((p) => p.id != productId).toList(),
    );
    Future.microtask(() => ref.invalidate(productsProvider));
  }

  Future<void> toggleAvailability(String productId, bool available) async {
    final updated = await ref
        .read(productRepositoryProvider)
        .toggleAvailability(productId, available);
    state = AsyncData([
      for (final p in state.value ?? []) if (p.id == productId) updated else p,
    ]);
    Future.microtask(() => ref.invalidate(productsProvider));
  }
}

final adminProductsProvider =
    AsyncNotifierProvider<AdminProductsNotifier, List<Product>>(
  AdminProductsNotifier.new,
);

class AdminCatalogExtrasNotifier extends AsyncNotifier<List<ProductExtra>> {
  @override
  Future<List<ProductExtra>> build() {
    return ref.read(productRepositoryProvider).getCatalogExtras();
  }

  Future<void> createExtra({
    required String name,
    required double price,
    String? imageUrl,
  }) async {
    final extra = ProductExtra(
      id: 'ex_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      price: price,
      imageUrl: imageUrl,
    );
    final created =
        await ref.read(productRepositoryProvider).createCatalogExtra(extra);
    state = AsyncData([...(state.value ?? []), created]);
    Future.microtask(() {
      ref.invalidate(productsProvider);
      ref.invalidate(adminProductsProvider);
    });
  }

  Future<void> updateExtra(ProductExtra extra) async {
    final updated =
        await ref.read(productRepositoryProvider).updateCatalogExtra(extra);
    state = AsyncData([
      for (final item in state.value ?? [])
        if (item.id == updated.id) updated else item,
    ]);
    Future.microtask(() {
      ref.invalidate(productsProvider);
      ref.invalidate(adminProductsProvider);
    });
  }

  Future<void> deleteExtra(String extraId) async {
    await ref.read(productRepositoryProvider).deleteCatalogExtra(extraId);
    state = AsyncData(
      (state.value ?? []).where((extra) => extra.id != extraId).toList(),
    );
    Future.microtask(() {
      ref.invalidate(productsProvider);
      ref.invalidate(adminProductsProvider);
    });
  }
}

final adminCatalogExtrasProvider =
    AsyncNotifierProvider<AdminCatalogExtrasNotifier, List<ProductExtra>>(
  AdminCatalogExtrasNotifier.new,
);

class AdminUsersNotifier extends AsyncNotifier<List<AdminUserModel>> {
  @override
  Future<List<AdminUserModel>> build() {
    return ref.read(adminRepositoryProvider).getUsers();
  }

  Future<void> createUser({
    required String name,
    required String phone,
    required String role,
    String? branchId,
    String? username,
    String? password,
  }) async {
    final user = AdminUserModel(
      id: 'u_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      role: role,
      phone: phone,
      isActive: true,
      branchId: branchId,
      username: username?.trim().toLowerCase(),
      password: password,
    );
    final created = await ref.read(adminRepositoryProvider).createUser(user);
    state = AsyncData([...(state.value ?? []), created]);
  }

  Future<void> updateUser(AdminUserModel user) async {
    final updated = await ref.read(adminRepositoryProvider).updateUser(user);
    state = AsyncData([
      for (final u in state.value ?? []) if (u.id == updated.id) updated else u,
    ]);
  }

  Future<void> deleteUser(String userId) async {
    await ref.read(adminRepositoryProvider).deleteUser(userId);
    state = AsyncData(
      (state.value ?? []).where((u) => u.id != userId).toList(),
    );
  }
}

final adminUsersProvider =
    AsyncNotifierProvider<AdminUsersNotifier, List<AdminUserModel>>(
  AdminUsersNotifier.new,
);

final adminReportsProvider = FutureProvider<AdminReportModel>((ref) async {
  ref.watch(adminBranchesProvider);
  return ref.read(adminRepositoryProvider).getReports();
});
