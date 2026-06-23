import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../core/widgets/product_thumbnail.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/product_combo_item.dart';
import '../../../presentation/providers/admin_provider.dart';

class AdminComboItemsEditor extends ConsumerWidget {
  const AdminComboItemsEditor({
    super.key,
    required this.items,
    required this.onChanged,
    this.excludeProductId,
    this.onSuggestPrice,
  });

  final List<ProductComboItem> items;
  final ValueChanged<List<ProductComboItem>> onChanged;
  final String? excludeProductId;
  final ValueChanged<double>? onSuggestPrice;

  List<Product> _selectableProducts(List<Product> products) {
    return products
        .where(
          (p) =>
              p.id != excludeProductId &&
              !p.isCombo &&
              p.isAvailable,
        )
        .toList()
      ..sort(
        (a, b) => localizedOrRaw(a.nameKey).compareTo(localizedOrRaw(b.nameKey)),
      );
  }

  double _suggestedPrice(List<Product> products) {
    var total = 0.0;
    for (final item in items) {
      final product = products.where((p) => p.id == item.productId).firstOrNull;
      if (product != null) {
        total += product.price * item.quantity;
      }
    }
    return total;
  }

  Future<void> _pickProduct(
    BuildContext context,
    List<Product> selectable,
  ) async {
    if (selectable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminComboNoProducts.tr())),
      );
      return;
    }

    final picked = await showModalBottomSheet<Product>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.35,
          maxChildSize: 0.92,
          builder: (_, controller) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(
                    LocaleKeys.adminComboPickProduct.tr(),
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: selectable.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final product = selectable[index];
                      final alreadyAdded =
                          items.any((i) => i.productId == product.id);
                      return ListTile(
                        leading: ProductThumbnail.fromProduct(
                          product: product,
                          width: 48,
                          height: 48,
                          compact: true,
                        ),
                        title: Text(localizedOrRaw(product.nameKey)),
                        subtitle: Text(FormatUtils.currency(product.price)),
                        trailing: alreadyAdded
                            ? Icon(Icons.check, color: AppColors.success)
                            : const Icon(Icons.add_circle_outline),
                        enabled: !alreadyAdded,
                        onTap: alreadyAdded
                            ? null
                            : () => Navigator.pop(ctx, product),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked == null) return;
    onChanged([
      ...items,
      ProductComboItem(
        productId: picked.id,
        nameKey: picked.nameKey,
      ),
    ]);
  }

  void _updateQuantity(int index, int quantity) {
    if (quantity < 1) return;
    final updated = [...items];
    updated[index] = updated[index].copyWith(quantity: quantity);
    onChanged(updated);
  }

  void _removeAt(int index) {
    onChanged([...items]..removeAt(index));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(adminProductsProvider).value ?? [];
    final selectable = _selectableProducts(products);
    final suggested = _suggestedPrice(products);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.adminProductComboItems.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              LocaleKeys.adminComboEmpty.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          )
        else
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final product =
                products.where((p) => p.id == item.productId).firstOrNull;
            return Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    if (product != null)
                      ProductThumbnail.fromProduct(
                        product: product,
                        width: 44,
                        height: 44,
                        compact: true,
                      )
                    else
                      const Icon(Icons.fastfood_outlined),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            localizedOrRaw(item.nameKey),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (product != null)
                            Text(
                              FormatUtils.currency(product.price),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: item.quantity > 1
                          ? () => _updateQuantity(index, item.quantity - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${item.quantity}'),
                    IconButton(
                      onPressed: () => _updateQuantity(index, item.quantity + 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                    IconButton(
                      onPressed: () => _removeAt(index),
                      icon: const Icon(Icons.close, color: AppColors.error),
                    ),
                  ],
                ),
              ),
            );
          }),
        OutlinedButton.icon(
          onPressed: () => _pickProduct(context, selectable),
          icon: const Icon(Icons.add),
          label: Text(LocaleKeys.adminComboAddItem.tr()),
        ),
        if (items.isNotEmpty && onSuggestPrice != null && suggested > 0) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => onSuggestPrice!(suggested),
              icon: const Icon(Icons.calculate_outlined),
              label: Text(
                LocaleKeys.adminComboSuggestPrice.tr(
                  namedArgs: {'amount': FormatUtils.currency(suggested)},
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
