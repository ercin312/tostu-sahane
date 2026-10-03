import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/analytics/meta_analytics.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/media/app_image.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../core/widgets/app_logo.dart';
import '../../../../../core/widgets/product_thumbnail.dart';
import '../../../../../core/widgets/provider_error_view.dart';
import '../../../../../shared/data/mock/mock_data.dart';
import '../../../../../shared/domain/entities/branch.dart';
import '../../../../../shared/domain/entities/campaign_banner.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../admin/presentation/providers/campaign_provider.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../cart/presentation/utils/branch_cart_guard.dart';
import '../providers/branch_provider.dart';
import '../../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../../../../shared/presentation/providers/pickup_settings_provider.dart';
import '../../../pickup/presentation/providers/fulfillment_mode_provider.dart';
import '../../../pickup/presentation/widgets/pickup_entry_button.dart';
import '../../../notifications/presentation/widgets/broadcast_open_listener.dart';
import '../widgets/home_campaign_products_section.dart';

class CustomerHomePage extends ConsumerWidget {
  const CustomerHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchProvider);
    final allBranches = ref.watch(branchesProvider);
    final products = ref.watch(filteredProductsProvider);
    final productsLoading = ref.watch(productsProvider).isLoading;
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final cartCount = ref.watch(cartItemCountProvider);
    final campaigns = ref.watch(activeCampaignBannersProvider);
    final visibleCategories = ref.watch(customerVisibleCategoriesProvider);

    ref.listen(waiterModeSettingsProvider, (previous, next) {
      final enabled = next.valueOrNull?.customerSahandaEnabled ?? true;
      if (!enabled &&
          ref.read(selectedCategoryProvider) == ProductCategory.sahanda) {
        ref.read(selectedCategoryProvider.notifier).state = ProductCategory.all;
      }
    });

    return branchAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        body: ProviderErrorView(provider: branchProvider),
      ),
      data: (branch) => _HomeContent(
        branch: branch,
        allBranches: allBranches.value ?? MockData.branches,
        products: products,
        productsLoading: productsLoading,
        selectedCategory: selectedCategory,
        cartCount: cartCount,
        campaigns: campaigns,
        visibleCategories: visibleCategories,
        onSelectBranch: (b) => selectBranchWithCartGuard(context, ref, b),
        onSelectCategory: (c) =>
            ref.read(selectedCategoryProvider.notifier).state = c,
        searchQuery: ref.watch(productSearchQueryProvider),
        onSearchChanged: (q) {
          ref.read(productSearchQueryProvider.notifier).state = q;
          final results = ref.read(filteredProductsProvider);
          MetaAnalytics.logSearchDebounced(q, resultCount: results.length);
        },
        onUseNearestBranch: () async {
          final nearest = await ref
              .read(branchProvider.notifier)
              .findNearestDeliveringBranch();
          if (!context.mounted) return;
          if (nearest == null) {
            await ref.read(branchProvider.notifier).selectNearestFromLocation();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(LocaleKeys.deliveryZoneUnavailable.tr())),
            );
            return;
          }
          await selectBranchWithCartGuard(context, ref, nearest);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LocaleKeys.locationNearestSelected.tr())),
          );
        },
      ),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({
    required this.branch,
    required this.allBranches,
    required this.products,
    required this.productsLoading,
    required this.selectedCategory,
    required this.cartCount,
    required this.campaigns,
    required this.visibleCategories,
    required this.onSelectBranch,
    required this.onSelectCategory,
    required this.onUseNearestBranch,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  final Branch branch;
  final List<Branch> allBranches;
  final List<Product> products;
  final bool productsLoading;
  final ProductCategory selectedCategory;
  final int cartCount;
  final List<CampaignBanner> campaigns;
  final List<ProductCategory> visibleCategories;
  final ValueChanged<Branch> onSelectBranch;
  final ValueChanged<ProductCategory> onSelectCategory;
  final VoidCallback onUseNearestBranch;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F2F4),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: const Color(0xFFF7F2F4),
            title: Row(
              children: [
                const AppLogo(height: 32),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  LocaleKeys.appName.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                ),
              ],
            ),
            actions: [
              const CustomerNotificationBell(),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.white,
                    shape: const CircleBorder(),
                  ),
                  icon: Badge(
                    isLabelVisible: cartCount > 0,
                    backgroundColor: AppColors.primary,
                    label: Text(
                      '$cartCount',
                      style: const TextStyle(color: AppColors.white),
                    ),
                    child: const Icon(Icons.shopping_bag_outlined),
                  ),
                  onPressed: () => context.push(RoutePaths.customerCart),
                ),
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: _BranchSelector(
                branch: branch,
                allBranches: allBranches,
                onSelect: onSelectBranch,
                onUseNearest: onUseNearestBranch,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: PickupEntryButton()),
          if (!branch.isOpenNow)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: AppColors.warning,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          LocaleKeys.branchClosedMessage.tr(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (campaigns.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: _SectionTitle(LocaleKeys.customerCampaigns.tr()),
              ),
            ),
            SliverToBoxAdapter(
              child: _CampaignCarousel(campaigns: campaigns),
            ),
          ],
          const SliverToBoxAdapter(child: HomeCampaignProductsSection()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: _SectionTitle(LocaleKeys.navMenu.tr()),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: LocaleKeys.customerSearchMenu.tr(),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => onSearchChanged(''),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                children: visibleCategories.map((category) {
                  final labelKey = MockData.categoryKeys[category];
                  final label = labelKey?.tr() ?? category.name;
                  final selected = selectedCategory == category;
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text(label),
                      selected: selected,
                      showCheckmark: false,
                      avatar: Icon(
                        _categoryIcon(category),
                        size: 16,
                        color: selected ? AppColors.white : AppColors.primary,
                      ),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      backgroundColor: AppColors.white,
                      shape: const StadiumBorder(),
                      side: BorderSide(
                        color: selected ? AppColors.primary : Colors.transparent,
                      ),
                      onSelected: (_) => onSelectCategory(category),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          if (productsLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (products.isEmpty)
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
                itemCount: products.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final product = products[index];
                  if (!product.isAvailable) return const SizedBox.shrink();
                  return _ProductCard(
                    product: product,
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
          ? _CartBar(
              count: cartCount,
              onTap: () => context.push(RoutePaths.customerCart),
            )
          : null,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
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
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
        ),
      ],
    );
  }
}

class _CampaignCarousel extends StatefulWidget {
  const _CampaignCarousel({required this.campaigns});

  final List<CampaignBanner> campaigns;

  @override
  State<_CampaignCarousel> createState() => _CampaignCarouselState();
}

class _CampaignCarouselState extends State<_CampaignCarousel> {
  late final PageController _controller;
  Timer? _autoSlideTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.9);
    if (widget.campaigns.length > 1) {
      _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted || !_controller.hasClients) return;
        setState(() {
          _currentPage = (_currentPage + 1) % widget.campaigns.length;
        });
        _controller.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onCampaignTap(BuildContext context, CampaignBanner banner) {
    if (banner.actionUrl != null && banner.actionUrl!.startsWith('/')) {
      context.push(banner.actionUrl!);
      return;
    }
    if (banner.title.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(localizedOrRaw(banner.title)),
        action: banner.actionLabel != null
            ? SnackBarAction(
                label: localizedOrRaw(banner.actionLabel!),
                onPressed: () {},
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.campaigns.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final banner = widget.campaigns[index];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _onCampaignTap(context, banner),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (banner.imageUrl != null &&
                            banner.imageUrl!.isNotEmpty)
                          AppImage(
                            source: banner.imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: const _CampaignFallback(),
                          )
                        else
                          const _CampaignFallback(),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00000000),
                                Color(0x99000000),
                              ],
                              stops: [0.45, 1],
                            ),
                          ),
                        ),
                        if (banner.title.trim().isNotEmpty)
                          Positioned(
                            left: AppSpacing.md,
                            right: AppSpacing.md,
                            bottom: AppSpacing.md,
                            child: Text(
                              localizedOrRaw(banner.title),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w800,
                                    height: 1.15,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (widget.campaigns.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.campaigns.length, (index) {
              final active = index == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : AppColors.divider,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

}

class _CampaignFallback extends StatelessWidget {
  const _CampaignFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF4D7A), AppColors.primary, AppColors.primaryDark],
        ),
      ),
    );
  }
}

class _BranchSelector extends StatelessWidget {
  const _BranchSelector({
    required this.branch,
    required this.allBranches,
    required this.onSelect,
    required this.onUseNearest,
  });

  final Branch branch;
  final List<Branch> allBranches;
  final ValueChanged<Branch> onSelect;
  final VoidCallback onUseNearest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _showBranchPicker(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.storefront_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                branch.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: branch.isOpenNow
                                    ? const Color(0xFF1FA971)
                                    : AppColors.warning,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          branch.distanceKm > 0
                              ? '${branch.address} · ${branch.distanceKm} km'
                              : branch.address,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (allBranches.length > 1)
                    IconButton(
                      tooltip: LocaleKeys.locationUseNearest.tr(),
                      onPressed: onUseNearest,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 36,
                        height: 36,
                      ),
                      icon: const Icon(Icons.my_location_rounded, size: 20),
                      color: AppColors.primary,
                    ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showBranchPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                title: Text(
                  LocaleKeys.customerBranchSelect.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              ...allBranches.map(
                (b) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: const Icon(Icons.store, color: AppColors.primary),
                  ),
                  title: Text(b.name),
                  subtitle: Text(b.address),
                  trailing: Text('${b.distanceKm} km'),
                  onTap: () {
                    onSelect(b);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }
}

class _ProductCard extends ConsumerWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pickupActive = ref.watch(customerPickupActiveProvider);
    final pickupSettings = ref.watch(pickupSettingsProvider).valueOrNull;
    final price = customerUnitPrice(
      product: product,
      pickupActive: pickupActive,
      settings: pickupSettings,
    );
    final discounted = pickupActive && price + 0.009 < product.price;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.white,
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
              SizedBox(
                width: 96,
                height: 96,
                child: ProductThumbnail.fromProduct(
                  product: product,
                  borderRadius: 16,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              localizedOrRaw(product.nameKey),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    height: 1.15,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (product.isCombo)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                LocaleKeys.customerComboBadge.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        localizedOrRaw(product.descriptionKey),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Text(
                            FormatUtils.currency(price),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (discounted) ...[
                            const SizedBox(width: 8),
                            Text(
                              FormatUtils.currency(product.price),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
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
                              Icons.arrow_forward_rounded,
                              color: AppColors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  const _CartBar({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_bag, color: AppColors.white),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        LocaleKeys.customerViewCart.tr(
                          namedArgs: {'count': '$count'},
                        ),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
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
    );
  }
}
