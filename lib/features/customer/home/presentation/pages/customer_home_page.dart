import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
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
        onSearchChanged: (q) =>
            ref.read(productSearchQueryProvider.notifier).state = q,
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
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            elevation: 0,
            scrolledUnderElevation: 0.5,
            backgroundColor: AppColors.white,
            title: Row(
              children: [
                const AppLogo(height: 28),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  LocaleKeys.appName.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            actions: [
              IconButton(
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
              const SizedBox(width: AppSpacing.xs),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: _BranchSelector(
                branch: branch,
                allBranches: allBranches,
                onSelect: onSelectBranch,
                onUseNearest: onUseNearestBranch,
              ),
            ),
          ),
          if (!branch.isOpenNow)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, color: AppColors.warning),
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
                  AppSpacing.md,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: Text(
                  LocaleKeys.customerCampaigns.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _CampaignCarousel(campaigns: campaigns),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  hintText: LocaleKeys.customerSearchMenu.tr(),
                  prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => onSearchChanged(''),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
                        size: 18,
                        color: selected ? AppColors.white : AppColors.primary,
                      ),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.white : AppColors.textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      backgroundColor: AppColors.white,
                      side: BorderSide(
                        color: selected ? AppColors.primary : AppColors.divider,
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
          height: 148,
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
                            errorWidget: _gradientFallback(banner, context),
                          )
                        else
                          _gradientFallback(banner, context),
                        if (banner.title.trim().isNotEmpty)
                          Positioned(
                            left: AppSpacing.md,
                            right: AppSpacing.md,
                            bottom: AppSpacing.md,
                            child: Text(
                              localizedOrRaw(banner.title),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
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

  Widget _gradientFallback(CampaignBanner banner, BuildContext context) {
    final hasTitle = banner.title.trim().isNotEmpty;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      alignment: hasTitle ? Alignment.bottomLeft : Alignment.center,
      padding: hasTitle ? const EdgeInsets.all(AppSpacing.md) : EdgeInsets.zero,
      child: hasTitle
          ? Text(
              localizedOrRaw(banner.title),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.white,
                  ),
            )
          : null,
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
          borderRadius: BorderRadius.circular(16),
          elevation: 0,
          shadowColor: Colors.black26,
          child: InkWell(
            onTap: () => _showBranchPicker(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.store, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Text(
                          branch.address,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (branch.distanceKm > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${branch.distanceKm} km',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  const Icon(Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: onUseNearest,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.my_location, size: 18),
          label: Text(LocaleKeys.locationUseNearest.tr()),
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: Colors.black12,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(18),
                ),
                child: SizedBox(
                  width: 108,
                  height: 108,
                  child: ProductThumbnail.fromProduct(
                    product: product,
                    borderRadius: 0,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
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
                                  ?.copyWith(fontWeight: FontWeight.w700),
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
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
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
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        FormatUtils.currency(product.price),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: Icon(Icons.arrow_forward_ios_rounded, size: 16),
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
