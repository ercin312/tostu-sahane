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
  // Mobil ve Windows aynı: ızgara dialog.
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (context) => const _WaiterAddonsGridDialog(),
  );
}

class _WaiterAddonsGridDialog extends ConsumerWidget {
  const _WaiterAddonsGridDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extrasAsync = ref.watch(catalogExtrasProvider);
    final extras = ref.watch(waiterCatalogExtrasProvider);
    final cart = ref.watch(waiterCartProvider);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.92,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      LocaleKeys.customerExtrasTitle.tr(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: extrasAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      Center(child: Text(LocaleKeys.commonError.tr())),
                  data: (_) {
                    if (extras.isEmpty) {
                      return Center(
                        child: Text(LocaleKeys.adminNoCatalogExtras.tr()),
                      );
                    }
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final count = extras.length;
                        final cols = count <= 4
                            ? count
                            : count <= 6
                                ? 3
                                : count <= 9
                                    ? 3
                                    : count <= 12
                                        ? 4
                                        : 5;
                        final rows = (count / cols).ceil();
                        final spacing = 8.0;
                        final cellW =
                            (constraints.maxWidth - spacing * (cols - 1)) /
                                cols;
                        final cellH =
                            (constraints.maxHeight - spacing * (rows - 1)) /
                                rows;
                        final side = cellW < cellH ? cellW : cellH;

                        return Center(
                          child: Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            alignment: WrapAlignment.center,
                            children: [
                              for (final extra in extras)
                                SizedBox(
                                  width: side,
                                  height: side,
                                  child: _ExtraGridTile(
                                    extra: extra,
                                    quantity: cart
                                        .where(
                                          (item) =>
                                              item.catalogExtra?.id ==
                                              extra.id,
                                        )
                                        .fold<int>(
                                          0,
                                          (sum, item) => sum + item.quantity,
                                        ),
                                    onTap: () => ref
                                        .read(waiterCartProvider.notifier)
                                        .addCatalogExtra(extra),
                                    onIncrement: () => ref
                                        .read(waiterCartProvider.notifier)
                                        .addCatalogExtra(extra),
                                    onDecrement: () {
                                      final line = cart.lastWhere(
                                        (item) =>
                                            item.catalogExtra?.id == extra.id,
                                        orElse: () => WaiterCartItem(
                                          catalogExtra: extra,
                                          quantity: 0,
                                        ),
                                      );
                                      if (line.catalogExtra?.id == extra.id) {
                                        ref
                                            .read(waiterCartProvider.notifier)
                                            .setQuantity(
                                              line.lineKey,
                                              line.quantity - 1,
                                            );
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(LocaleKeys.commonOk.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtraGridTile extends StatelessWidget {
  const _ExtraGridTile({
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
          padding: const EdgeInsets.all(6),
          child: Column(
            children: [
              Expanded(
                child: ProductThumbnail(
                  category: ProductCategory.drink,
                  imageUrl: extra.imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 8,
                  imageColorValue: 0xFFE3F2FD,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      localizedOrRaw(extra.name),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    FormatUtils.currency(extra.price),
                    maxLines: 1,
                    softWrap: false,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed: quantity > 0 ? onDecrement : null,
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                  ),
                  Text(
                    '$quantity',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    onPressed: onIncrement,
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
