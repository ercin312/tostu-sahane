import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../core/widgets/product_thumbnail.dart';
import '../../../../../core/widgets/provider_error_view.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../shared/data/mock/mock_data.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../customer/home/presentation/providers/branch_provider.dart';

class BranchMenuPage extends ConsumerWidget {
  const BranchMenuPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        title: Text(
          LocaleKeys.branchMenuTitle.tr(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: const [RoleLogoutAction()],
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => ProviderErrorView(provider: productsProvider),
        data: (products) {
          if (products.isEmpty) {
            return Center(
              child: Text(
                LocaleKeys.customerCartEmpty.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final product = products[index];
              return _BranchMenuProductTile(
                product: product,
                onToggle: () => ref
                    .read(productsProvider.notifier)
                    .toggleAvailability(product.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _BranchMenuProductTile extends StatelessWidget {
  const _BranchMenuProductTile({
    required this.product,
    required this.onToggle,
  });

  final Product product;
  final VoidCallback onToggle;

  String get _categoryLabel {
    final key = MockData.categoryKeys[product.category];
    return key?.tr() ?? product.category.name;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: ProductThumbnail.fromProduct(
                  product: product,
                  borderRadius: 0,
                  compact: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localizedOrRaw(product.nameKey),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _categoryLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    FormatUtils.currency(product.price),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Switch(
                  value: product.isAvailable,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.45),
                  thumbColor: WidgetStateProperty.all(AppColors.primary),
                  onChanged: (_) => onToggle(),
                ),
                Text(
                  product.isAvailable
                      ? LocaleKeys.branchAvailable.tr()
                      : LocaleKeys.branchSoldOut.tr(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: product.isAvailable
                            ? AppColors.success
                            : AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
