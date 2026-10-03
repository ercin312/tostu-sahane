import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/analytics/meta_analytics.dart';
import '../../../../../core/auth/guest_access.dart';
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
import '../../../../../shared/presentation/providers/pickup_settings_provider.dart';
import '../../../checkout/presentation/providers/coupon_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/delivery_providers.dart';
import '../widgets/campaign_picker_sheet.dart';
import '../../../../../shared/presentation/providers/delivery_settings_provider.dart';
import '../../../pickup/presentation/providers/fulfillment_mode_provider.dart';

class CartPage extends ConsumerWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final products = ref.watch(productsProvider).value ?? [];
    final subtotal = ref.watch(cartSubtotalProvider);
    final meetsMinimum = ref.watch(cartMeetsMinimumProvider);
    final total = ref.watch(checkoutTotalProvider);
    final discount = ref.watch(checkoutDiscountProvider);
    final discountLabel = ref.watch(checkoutDiscountLabelProvider);
    final deliveryFee = ref.watch(deliveryFeeProvider);
    final freeDeliveryMinOrder = ref.watch(effectiveFreeDeliveryMinOrderProvider);
    final pickupActive = ref.watch(customerPickupActiveProvider);
    final minimumOrder = ref.watch(effectiveMinimumOrderProvider);
    final catalog =
        ref.watch(catalogExtrasProvider).value ?? MockData.catalogExtras;

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.customerCartTitle.tr())),
      body: cart.isEmpty
          ? const _EmptyCartSuggestions()
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
                            .updateQuantity(item.id, (item.quantity + 1).round()),
                        onDecrease: () => ref
                            .read(cartProvider.notifier)
                            .updateQuantity(item.id, (item.quantity - 1).round()),
                        onRemove: () => ref
                            .read(cartProvider.notifier)
                            .removeItem(item.id),
                      );
                    },
                  ),
                ),
                const _CartUpsellBand(),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    color: AppColors.white,
                    child: Column(
                      children: [
                      if (pickupActive)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            LocaleKeys.pickupCartBanner.tr(),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      _PriceRow(
                        label: LocaleKeys.customerSubtotal.tr(),
                        value: FormatUtils.currency(subtotal),
                      ),
                      const CampaignPickerTile(),
                      const SizedBox(height: AppSpacing.sm),
                      _PriceRow(
                        label: pickupActive
                            ? LocaleKeys.navPickup.tr()
                            : LocaleKeys.customerDeliveryFee.tr(),
                        value: pickupActive
                            ? LocaleKeys.pickupNoDeliveryFee.tr()
                            : deliveryFee <= 0
                                ? LocaleKeys.customerDeliveryFree.tr()
                                : FormatUtils.currency(deliveryFee),
                      ),
                      if (!pickupActive && deliveryFee <= 0)
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
                      if (!pickupActive &&
                          deliveryFee > 0 &&
                          subtotal < freeDeliveryMinOrder)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            LocaleKeys.customerBelowMinDeliveryFeeHint.tr(
                              namedArgs: {
                                'amount': freeDeliveryMinOrder.toStringAsFixed(0),
                                'fee': deliveryFee.toStringAsFixed(0),
                              },
                            ),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.warning,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (discount > 0) ...[
                        const SizedBox(height: AppSpacing.xs),
                        _PriceRow(
                          label: discountLabel ??
                              LocaleKeys.campaignPickerCartCta.tr(),
                          value: '-${FormatUtils.currency(discount)}',
                        ),
                      ],
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
                              'amount': minimumOrder.toStringAsFixed(0),
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
                            ? () {
                                if (!GuestAccess.requireAuth(
                                  context,
                                  ref,
                                  redirectTo: RoutePaths.customerCheckout,
                                )) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        LocaleKeys.authLoginRequiredOrder.tr(),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                final cart = ref.read(cartProvider);
                                final total = ref.read(cartTotalProvider);
                                final numItems = cart
                                    .fold<double>(0, (s, i) => s + i.quantity)
                                    .round();
                                MetaAnalytics.logInitiatedCheckout(
                                  totalPrice: total,
                                  numItems: numItems,
                                  productIds: cart
                                      .map((e) => e.productId)
                                      .toSet()
                                      .toList(),
                                );
                                context.push(RoutePaths.customerCheckout);
                              }
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

class _CartUpsellBand extends ConsumerWidget {
  const _CartUpsellBand();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(cartUpsellProductsProvider);
    if (products.isEmpty) return const SizedBox.shrink();

    final pickupActive = ref.watch(customerPickupActiveProvider);
    final pickupSettings = ref.watch(pickupSettingsProvider).valueOrNull;

    return Material(
      color: const Color(0xFFFFF7F8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.customerCartUpsellTitle.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final product = products[index];
                  final price = customerUnitPrice(
                    product: product,
                    pickupActive: pickupActive,
                    settings: pickupSettings,
                  );
                  return _UpsellChip(
                    product: product,
                    price: price,
                    onAdd: () => _addUpsell(context, ref, product, price),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addUpsell(
    BuildContext context,
    WidgetRef ref,
    Product product,
    double price,
  ) {
    final branch = ref.read(branchProvider).value;
    if (branch == null) return;
    ref.read(cartProvider.notifier).addItem(
          CartItem(
            id: generateCartItemId(),
            productId: product.id,
            productNameKey: product.nameKey,
            unitPrice: price,
            quantity: 1,
            portionKey: product.isCombo ? null : LocaleKeys.portionNormal,
            productCategory: product.category.name,
          ),
          branchId: branch.id,
        );
    MetaAnalytics.logAddToCart(
      productId: product.id,
      productName: localizedOrRaw(product.nameKey),
      price: price,
      quantity: 1,
    );
  }
}

class _UpsellChip extends StatelessWidget {
  const _UpsellChip({
    required this.product,
    required this.price,
    required this.onAdd,
  });

  final Product product;
  final double price;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: ProductThumbnail.fromProduct(
                  product: product,
                  borderRadius: 12,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      localizedOrRaw(product.nameKey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      FormatUtils.currency(price),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: AppColors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCartSuggestions extends ConsumerWidget {
  const _EmptyCartSuggestions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(productsProvider).isLoading;
    final suggestions = ref.watch(cartSuggestionProductsProvider);
    final pickupActive = ref.watch(customerPickupActiveProvider);
    final pickupSettings = ref.watch(pickupSettingsProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.customerCartEmpty.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      LocaleKeys.customerCartEmptyHint.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (suggestions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                LocaleKeys.orderRecommendedProducts.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final product in suggestions) ...[
            _SuggestionTile(
              product: product,
              price: customerUnitPrice(
                product: product,
                pickupActive: pickupActive,
                settings: pickupSettings,
              ),
              onTap: () => context.push(RoutePaths.customerProduct(product.id)),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.product,
    required this.price,
    required this.onTap,
  });

  final Product product;
  final double price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final discounted = price + 0.009 < product.price;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: ProductThumbnail.fromProduct(
                  product: product,
                  borderRadius: 14,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedOrRaw(product.nameKey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          FormatUtils.currency(price),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (discounted) ...[
                          const SizedBox(width: 6),
                          Text(
                            FormatUtils.currency(product.price),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: AppColors.white, size: 18),
              ),
            ],
          ),
        ),
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
          Text(FormatUtils.quantity(item.quantity)),
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
