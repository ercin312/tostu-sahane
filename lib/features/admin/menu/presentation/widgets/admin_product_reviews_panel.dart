import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../customer/product_detail/presentation/providers/product_reviews_provider.dart';
import '../../../presentation/providers/admin_provider.dart';

class AdminProductReviewsPanel extends ConsumerWidget {
  const AdminProductReviewsPanel({
    super.key,
    this.itemLimit,
    this.showEmptyState = false,
  });

  final int? itemLimit;
  final bool showEmptyState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingProductReviewsProvider);
    final products = ref.watch(adminProductsProvider).value ?? [];

    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
      data: (pending) {
        if (pending.isEmpty) {
          if (!showEmptyState) return const SizedBox.shrink();
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(LocaleKeys.adminPendingReviewsEmpty.tr()),
            ),
          );
        }

        final visible = itemLimit == null
            ? pending
            : pending.take(itemLimit!).toList();

        return Card(
          margin: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.adminPendingReviewsTitle.tr(
                    namedArgs: {'count': '${pending.length}'},
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...visible.map((review) {
                  final product = products
                      .where((p) => p.id == review.productId)
                      .firstOrNull;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(localizedOrRaw(product?.nameKey ?? review.productId)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          review.customerName,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                        Row(
                          children: List.generate(
                            review.rating,
                            (_) => const Icon(Icons.star, color: Colors.amber, size: 14),
                          ),
                        ),
                        Text(review.comment, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: LocaleKeys.adminReviewApprove.tr(),
                          icon: const Icon(Icons.check_circle, color: AppColors.success),
                          onPressed: () => ref
                              .read(productReviewsNotifierProvider.notifier)
                              .approve(review.id, review.productId),
                        ),
                        IconButton(
                          tooltip: LocaleKeys.adminReviewReject.tr(),
                          icon: const Icon(Icons.cancel, color: AppColors.error),
                          onPressed: () => ref
                              .read(productReviewsNotifierProvider.notifier)
                              .reject(review.id, review.productId),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}
