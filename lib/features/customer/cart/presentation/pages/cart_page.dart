import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/cart_item_display_utils.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../core/widgets/product_thumbnail.dart';
import '../../../../../shared/data/mock/mock_data.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/product_extra.dart';
import '../../../home/presentation/providers/branch_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/delivery_providers.dart';
import '../../../../../shared/presentation/providers/delivery_settings_provider.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final products = ref.watch(productsProvider).value ?? [];
    final subtotal = ref.watch(cartSubtotalProvider);
    final meetsMinimum = ref.watch(cartMeetsMinimumProvider);
    final total = ref.watch(cartTotalProvider);
    final deliveryFee = ref.watch(deliveryFeeProvider);
    final freeDeliveryMinOrder = ref.watch(effectiveFreeDeliveryMinOrderProvider);
    final branch = ref.watch(branchProvider).value;
    final catalog =
        ref.watch(catalogExtrasProvider).value ?? MockData.catalogExtras;

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.customerCartTitle.tr())),
      body: cart.isEmpty
          ? Center(child: Text(LocaleKeys.customerCartEmpty.tr()))
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: cart.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      final product = products
                          .where((p) => p.id == item.productId)
                          .firstOrNull;
                      return _CartItemTile(
                        item: item,
                        product: product,
                        catalog: catalog,
                        onIncrease: () => ref
                            .read(cartProvider.notifier)
                            .updateQuantity(item.id, item.quantity + 1),
                        onDecrease: () => ref
                            .read(cartProvider.notifier)
                            .updateQuantity(item.id, item.quantity - 1),
                        onRemove: () => ref
                            .read(cartProvider.notifier)
                            .removeItem(item.id),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    color: AppColors.white,
                    child: Column(
                      children: [
                      _PriceRow(
                        label: LocaleKeys.customerSubtotal.tr(),
                        value: FormatUtils.currency(subtotal),
                      ),
                      _PriceRow(
                        label: LocaleKeys.customerDeliveryFee.tr(),
                        value: deliveryFee <= 0
                            ? LocaleKeys.customerDeliveryFree.tr()
                            : FormatUtils.currency(deliveryFee),
                      ),
                      if (deliveryFee <= 0)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            LocaleKeys.customerDeliveryFreeHint.tr(
                              namedArgs: {
                                'amount': freeDeliveryMinOrder
                                    .toStringAsFixed(0),
                              },
                            ),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.success,
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const Divider(),
                      _PriceRow(
                        label: LocaleKeys.customerTotal.tr(),
                        value: FormatUtils.currency(total),
                        bold: true,
                      ),
                      if (!meetsMinimum) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          LocaleKeys.customerMinOrderWarning.tr(
                            namedArgs: {
                              'amount':
                                  AppConstants.minimumOrderAmount.toStringAsFixed(0),
                            },
                          ),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.warning,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      AppButton(
                        labelKey: LocaleKeys.customerGoCheckout,
                        onPressed: meetsMinimum
                            ? () => context.push(RoutePaths.customerCheckout)
                            : null,
                      ),
                    ],
                  ),
                ),
                ),
              ],
            ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    this.product,
    required this.catalog,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  final CartItem item;
  final Product? product;
  final List<ProductExtra> catalog;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (product != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ProductThumbnail.fromProduct(
                product: product!,
                width: 64,
                height: 64,
                compact: true,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedOrRaw(item.productNameKey),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (CartItemDisplayUtils.extraLabels(item, catalog).isNotEmpty)
                  Text(
                    '+ ${CartItemDisplayUtils.extraLabels(item, catalog).join(', ')}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                if (item.portionKey != null)
                  Text(
                    localizedOrRaw(item.portionKey!),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                Text(FormatUtils.currency(item.unitPrice)),
              ],
            ),
          ),
          IconButton(onPressed: onDecrease, icon: const Icon(Icons.remove)),
          Text('${item.quantity}'),
          IconButton(onPressed: onIncrease, icon: const Icon(Icons.add)),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleLarge
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}
