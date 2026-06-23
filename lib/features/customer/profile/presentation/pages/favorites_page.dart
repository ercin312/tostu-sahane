import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/customer_product_card.dart';
import '../../../home/presentation/providers/branch_provider.dart';
import '../providers/favorites_provider.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider).value ?? [];
    final products = ref.watch(productsProvider).value ?? [];
    final favoriteProducts =
        products.where((p) => favorites.contains(p.id)).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(LocaleKeys.profileFavorites.tr()),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: favoriteProducts.isEmpty
          ? Center(
              child: Text(
                LocaleKeys.favoritesEmpty.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: favoriteProducts.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final product = favoriteProducts[index];
                return CustomerProductCard(
                  product: product,
                  onTap: () => context.push(
                    RoutePaths.customerProduct(product.id),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    onPressed: () => ref
                        .read(favoritesProvider.notifier)
                        .toggle(product.id),
                  ),
                );
              },
            ),
    );
  }
}
