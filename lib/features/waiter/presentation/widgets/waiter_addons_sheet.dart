import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/utils/localized_text.dart';
import '../../../../core/widgets/product_thumbnail.dart';
import '../../../customer/home/presentation/providers/branch_provider.dart';
import '../../../../shared/domain/entities/product.dart';
import '../../../../shared/domain/entities/product_extra.dart';
import '../providers/waiter_cart_provider.dart';
import '../providers/waiter_products_provider.dart';

Future<void> showWaiterAddonsSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _WaiterAddonsSheet(),
  );
}

class _WaiterAddonsSheet extends ConsumerWidget {
  const _WaiterAddonsSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extrasAsync = ref.watch(catalogExtrasProvider);
    final extras = ref.watch(waiterCatalogExtrasProvider);
    final cart = ref.watch(waiterCartProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                LocaleKeys.customerExtrasTitle.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Expanded(
              child: extrasAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    Center(child: Text(LocaleKeys.commonError.tr())),
                data: (_) {
                  if (extras.isEmpty) {
                    return Center(
                      child: Text(LocaleKeys.adminNoCatalogExtras.tr()),
                    );
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    itemCount: extras.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final extra = extras[index];
                      final qty = cart
                          .where((item) => item.catalogExtra?.id == extra.id)
                          .fold<int>(0, (sum, item) => sum + item.quantity);
                      return _ExtraQtyRow(
                        extra: extra,
                        quantity: qty,
                        onTap: () => ref
                            .read(waiterCartProvider.notifier)
                            .addCatalogExtra(extra),
                        onIncrement: () => ref
                            .read(waiterCartProvider.notifier)
                            .addCatalogExtra(extra),
                        onDecrement: () {
                          final line = cart.lastWhere(
                            (item) => item.catalogExtra?.id == extra.id,
                            orElse: () => WaiterCartItem(
                              catalogExtra: extra,
                              quantity: 0,
                            ),
                          );
                          if (line.catalogExtra?.id == extra.id) {
                            ref
                                .read(waiterCartProvider.notifier)
                                .setQuantity(line.lineKey, line.quantity - 1);
                          }
                        },
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(LocaleKeys.commonOk.tr()),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExtraQtyRow extends StatelessWidget {
  const _ExtraQtyRow({
    required this.extra,
    required this.quantity,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
  });

  final ProductExtra extra;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final thumbnail = ProductThumbnail(
      category: ProductCategory.drink,
      imageUrl: extra.imageUrl,
      width: 56,
      height: 56,
      borderRadius: 10,
      imageColorValue: 0xFFE3F2FD,
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: quantity > 0 ? AppColors.primary : AppColors.divider,
              width: quantity > 0 ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              thumbnail,
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedOrRaw(extra.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      FormatUtils.currency(extra.price),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: quantity > 0 ? onDecrement : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$quantity',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: onIncrement,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
