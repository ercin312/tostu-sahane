import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../core/widgets/product_thumbnail.dart';
import '../../../../../shared/data/mock/mock_data.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/product_extra.dart';
import '../../../../customer/cart/presentation/providers/cart_provider.dart';
import '../../../home/presentation/providers/branch_provider.dart';
import '../../../profile/presentation/providers/favorites_provider.dart';
import '../widgets/product_extras_section.dart';
import '../widgets/product_reviews_section.dart';
import '../providers/product_reviews_provider.dart';

class ProductDetailPage extends ConsumerStatefulWidget {
  const ProductDetailPage({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends ConsumerState<ProductDetailPage> {
  int _quantity = 1;
  String _portionKey = LocaleKeys.portionNormal;
  final _selectedExtraIds = <String>{};
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  double _extrasTotal(Product product) {
    return product.extras
        .where((e) => _selectedExtraIds.contains(e.id))
        .fold<double>(0, (sum, e) => sum + e.price);
  }

  double _unitPrice(Product product) {
    var price = product.price + _extrasTotal(product);
    if (_portionKey == LocaleKeys.portionLarge) {
      price += MockData.largePortionExtra;
    }
    return price;
  }

  List<String> _selectedOptionLabels(Product product) {
    return product.extras
        .where((e) => _selectedExtraIds.contains(e.id))
        .map((e) => e.id)
        .toList();
  }

  void _toggleExtra(ProductExtra extra) {
    setState(() {
      if (_selectedExtraIds.contains(extra.id)) {
        _selectedExtraIds.remove(extra.id);
      } else {
        _selectedExtraIds.add(extra.id);
      }
    });
  }

  void _addToCart(Product product) {
    final branch = ref.read(branchProvider).value;
    if (branch == null) return;
    ref.read(cartProvider.notifier).addItem(
          CartItem(
            id: generateCartItemId(),
            productId: product.id,
            productNameKey: product.nameKey,
            unitPrice: product.isCombo
                ? product.price + _extrasTotal(product)
                : _unitPrice(product),
            quantity: _quantity,
            selectedOptions: _selectedOptionLabels(product),
            portionKey: product.isCombo ? null : _portionKey,
            note: _noteController.text.isEmpty ? null : _noteController.text,
          ),
          branchId: branch.id,
        );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return productsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        body: Center(child: Text(LocaleKeys.commonError.tr())),
      ),
      data: (products) {
        final product =
            products.where((p) => p.id == widget.productId).firstOrNull;
        if (product == null) {
          return Scaffold(
            body: Center(child: Text(LocaleKeys.commonError.tr())),
          );
        }

        final unitPrice = product.isCombo
            ? product.price + _extrasTotal(product)
            : _unitPrice(product);
        final isFavorite = ref.watch(isFavoriteProvider(product.id));
        final displayExtras = product.extras;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: AppColors.white,
                leading: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: AppColors.white,
                    child: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  ),
                  onPressed: () => context.pop(),
                ),
                actions: [
                  IconButton(
                    icon: CircleAvatar(
                      backgroundColor: AppColors.white,
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? AppColors.primary : AppColors.textPrimary,
                      ),
                    ),
                    onPressed: () =>
                        ref.read(favoritesProvider.notifier).toggle(product.id),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: ProductThumbnail.fromProduct(
                    product: product,
                    width: double.infinity,
                    height: double.infinity,
                    borderRadius: 0,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizedOrRaw(product.nameKey),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        FormatUtils.currency(product.price),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Builder(
                        builder: (context) {
                          final stats = ref.watch(
                            productReviewStatsProvider(product.id),
                          );
                          if (stats.count == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Row(
                              children: [
                                ...List.generate(
                                  5,
                                  (i) => Icon(
                                    i < stats.average.round()
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 18,
                                    color: Colors.amber,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${stats.average.toStringAsFixed(1)} (${stats.count})',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        localizedOrRaw(product.descriptionKey),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              if (product.isCombo && product.comboItems.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.white,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocaleKeys.customerComboIncludes.tr(),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ...product.comboItems.map(
                          (item) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.check_circle_outline,
                                color: AppColors.success),
                            title: Text(localizedOrRaw(item.nameKey)),
                            trailing: Text('x${item.quantity}'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.white,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: ProductExtrasSection(
                    extras: displayExtras,
                    selectedIds: _selectedExtraIds,
                    onToggle: _toggleExtra,
                  ),
                ),
              ),
              if (!product.isCombo)
                SliverToBoxAdapter(
                  child: Container(
                    color: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocaleKeys.customerPortionTitle.tr(),
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.sm,
                        children: [
                          _PortionChip(
                            label: LocaleKeys.portionNormal.tr(),
                            selected: _portionKey == LocaleKeys.portionNormal,
                            onTap: () => setState(
                              () => _portionKey = LocaleKeys.portionNormal,
                            ),
                          ),
                          _PortionChip(
                            label: LocaleKeys.portionLarge.tr(),
                            selected: _portionKey == LocaleKeys.portionLarge,
                            onTap: () => setState(
                              () => _portionKey = LocaleKeys.portionLarge,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Container(
                  color: AppColors.white,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.customerNotesHint.tr(),
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: ProductReviewsSection(product: product),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    _QuantityStepper(
                      quantity: _quantity,
                      onDecrement: _quantity > 1
                          ? () => setState(() => _quantity--)
                          : null,
                      onIncrement: () => setState(() => _quantity++),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _addToCart(product),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          '${LocaleKeys.customerAddToCart.tr()} · ${FormatUtils.currency(unitPrice * _quantity)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PortionChip extends StatelessWidget {
  const _PortionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary.withValues(alpha: 0.12),
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.primary : AppColors.textPrimary,
      ),
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.divider,
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onDecrement,
            icon: const Icon(Icons.remove, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          Text(
            '$quantity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          IconButton(
            onPressed: onIncrement,
            icon: const Icon(Icons.add, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
