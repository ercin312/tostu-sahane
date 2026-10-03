import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../core/widgets/product_thumbnail.dart';
import '../../../../../shared/data/mock/mock_data.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/promotion_campaign.dart';
import '../../../../../shared/presentation/providers/pickup_settings_provider.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../cart/presentation/providers/delivery_providers.dart';
import '../../../home/presentation/providers/branch_provider.dart';
import '../widgets/pickup_entry_button.dart';

class CustomerPickupPage extends ConsumerStatefulWidget {
  const CustomerPickupPage({super.key});

  @override
  ConsumerState<CustomerPickupPage> createState() => _CustomerPickupPageState();
}

class _CustomerPickupPageState extends ConsumerState<CustomerPickupPage> {
  ProductCategory _category = ProductCategory.all;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(pickupSettingsProvider);
    final products = ref.watch(productsProvider).value ?? const <Product>[];
    final categories = ref.watch(customerVisibleCategoriesProvider);
    final cartCount = ref.watch(cartItemCountProvider);
    final cartTotal = ref.watch(checkoutTotalProvider);
    final branch = ref.watch(branchProvider).value;

    return settingsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(title: Text(LocaleKeys.navPickup.tr())),
        body: Center(child: Text(LocaleKeys.commonError.tr())),
      ),
      data: (settings) {
        if (!settings.enabled) {
          return Scaffold(
            appBar: AppBar(title: Text(LocaleKeys.navPickup.tr())),
            body: Center(child: Text(LocaleKeys.adminPickupEnabledHint.tr())),
          );
        }

        final visible = products.where((product) {
          if (!product.isAvailable) return false;
          if (_category == ProductCategory.all) return true;
          return product.category == _category;
        }).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF7F2F4),
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 328,
                backgroundColor: AppColors.primaryDark,
                foregroundColor: AppColors.white,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: ClipRect(
                    child: DecoratedBox(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFF4D7A),
                          AppColors.primary,
                          AppColors.primaryDark,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 48, 20, 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE14A),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                settings.badgeText.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF5A3B00),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              settings.headline,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              branch == null
                                  ? settings.subtitle
                                  : '${branch.name} · ${settings.subtitle}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.white.withValues(alpha: 0.92),
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _HeaderPerk(
                                  icon: Icons.schedule_rounded,
                                  label: LocaleKeys.pickupReadyIn.tr(
                                    namedArgs: {
                                      'minutes': '${settings.readyMinutes}',
                                    },
                                  ),
                                ),
                                _HeaderPerk(
                                  icon: Icons.delivery_dining_outlined,
                                  label: LocaleKeys.pickupPerkNoFee.tr(),
                                ),
                                _HeaderPerk(
                                  icon: Icons.payments_outlined,
                                  label: LocaleKeys.pickupPerkPayAtStore.tr(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.white,
                                  backgroundColor:
                                      AppColors.white.withValues(alpha: 0.16),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () async {
                                  final switched =
                                      await switchToDelivery(context, ref);
                                  if (switched && context.mounted) {
                                    context.pop();
                                  }
                                },
                                icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                                label: Text(LocaleKeys.pickupSwitchToDelivery.tr()),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                  ),
                ),
              ),
              if (settings.activeCampaigns.isNotEmpty)
                SliverToBoxAdapter(
                  child: _PickupCampaignStrip(
                    campaigns: settings.activeCampaigns,
                  ),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    children: categories.map((category) {
                      final labelKey = MockData.categoryKeys[category];
                      final selected = _category == category;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(labelKey?.tr() ?? category.name),
                          selected: selected,
                          showCheckmark: false,
                          avatar: Icon(
                            _categoryIcon(category),
                            size: 16,
                            color: selected ? AppColors.white : AppColors.primary,
                          ),
                          selectedColor: AppColors.primary,
                          backgroundColor: AppColors.white,
                          shape: const StadiumBorder(),
                          side: BorderSide(
                            color: selected ? AppColors.primary : Colors.transparent,
                          ),
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (visible.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      LocaleKeys.customerCartEmpty.tr(),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  sliver: SliverList.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final product = visible[index];
                      final price = settings.priceFor(product.id, product.price);
                      return _PickupProductTile(
                        product: product,
                        price: price,
                        menuPrice: product.price,
                        onTap: () => context.push(
                          RoutePaths.customerProduct(product.id),
                        ),
                      );
                    },
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          ),
          bottomNavigationBar: cartCount > 0
              ? Container(
                  color: AppColors.white,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => context.push(RoutePaths.customerCart),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.shopping_bag_rounded,
                                    color: AppColors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '${LocaleKeys.customerViewCart.tr(namedArgs: {'count': '$cartCount'})} · ${FormatUtils.currency(cartTotal)}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: AppColors.white,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  IconData _categoryIcon(ProductCategory category) {
    return switch (category) {
      ProductCategory.tost => Icons.lunch_dining_rounded,
      ProductCategory.sahanda => Icons.egg_alt_rounded,
      ProductCategory.drink => Icons.local_cafe_rounded,
      ProductCategory.snack => Icons.fastfood_rounded,
      ProductCategory.combo => Icons.restaurant_menu_rounded,
      ProductCategory.all => Icons.grid_view_rounded,
    };
  }
}

class _HeaderPerk extends StatelessWidget {
  const _HeaderPerk({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupCampaignStrip extends StatelessWidget {
  const _PickupCampaignStrip({required this.campaigns});

  final List<PromotionCampaign> campaigns;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            LocaleKeys.pickupCampaigns.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: campaigns.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final campaign = campaigns[index];
              final detail = switch (campaign.type) {
                PromotionType.percentDiscount =>
                  '%${campaign.value.toStringAsFixed(0)}',
                PromotionType.fixedDiscount =>
                  FormatUtils.currency(campaign.value),
                PromotionType.freeDrinks =>
                  LocaleKeys.adminPromotionTypeFreeDrinks.tr(),
                PromotionType.freeItem =>
                  LocaleKeys.adminPromotionTypeFreeItem.tr(),
                PromotionType.buyXGetY =>
                  '${campaign.buyQuantity} al ${campaign.freeQuantity}',
                PromotionType.freeDelivery =>
                  LocaleKeys.adminPromotionTypeFreeDelivery.tr(),
              };
              return Container(
                width: 230,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF4D7A), AppColors.primaryDark],
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.local_offer_rounded,
                      color: Color(0xFFFFE14A),
                      size: 18,
                    ),
                    const Spacer(),
                    Text(
                      campaign.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: const TextStyle(
                        color: Color(0xFFFFE14A),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    if (campaign.minOrderAmount > 0)
                      Text(
                        'min ${FormatUtils.currency(campaign.minOrderAmount)}',
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PickupProductTile extends StatelessWidget {
  const _PickupProductTile({
    required this.product,
    required this.price,
    required this.menuPrice,
    required this.onTap,
  });

  final Product product;
  final double price;
  final double menuPrice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final discounted = price + 0.009 < menuPrice;
    final percent = discounted && menuPrice > 0
        ? ((1 - price / menuPrice) * 100).round()
        : 0;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3A1020).withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: ProductThumbnail.fromProduct(
                      product: product,
                      borderRadius: 16,
                    ),
                  ),
                  if (percent > 0)
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE14A),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '-%$percent',
                          style: const TextStyle(
                            color: Color(0xFF5A3B00),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedOrRaw(product.nameKey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      localizedOrRaw(product.descriptionKey),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          FormatUtils.currency(price),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        if (discounted) ...[
                          const SizedBox(width: 8),
                          Text(
                            FormatUtils.currency(menuPrice),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                  decoration: TextDecoration.lineThrough,
                                ),
                          ),
                        ],
                        const Spacer(),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: AppColors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
