import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../menu/presentation/widgets/admin_catalog_extras_tab.dart';
import '../../../menu/presentation/widgets/admin_product_editor_sheet.dart';
import '../../../presentation/providers/admin_provider.dart';
import '../../../presentation/widgets/admin_form_dialogs.dart';

class AdminWaiterMenuTab extends ConsumerWidget {
  const AdminWaiterMenuTab({super.key});

  static String _categoryLabel(Product product) {
    if (product.isCombo || product.category == ProductCategory.combo) {
      return LocaleKeys.customerCategoryCombo.tr();
    }
    return switch (product.category) {
      ProductCategory.tost => LocaleKeys.customerCategoryTost.tr(),
      ProductCategory.sahanda => LocaleKeys.customerCategorySahanda.tr(),
      ProductCategory.drink => LocaleKeys.customerCategoryDrink.tr(),
      ProductCategory.snack => LocaleKeys.waiterPosSides.tr(),
      ProductCategory.combo => LocaleKeys.customerCategoryCombo.tr(),
      ProductCategory.all => product.category.name,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(adminProductsProvider);

    return productsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
      data: (products) {
        final waiterProducts = products
            .where(
              (p) =>
                  p.category == ProductCategory.tost ||
                  p.category == ProductCategory.sahanda ||
                  p.category == ProductCategory.drink ||
                  p.category == ProductCategory.snack ||
                  p.isCombo ||
                  p.category == ProductCategory.combo,
            )
            .toList()
          ..sort(
            (a, b) =>
                localizedOrRaw(a.nameKey).compareTo(localizedOrRaw(b.nameKey)),
          );

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text(
              LocaleKeys.adminWaiterMenuTabHint.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: () => showAdminProductEditor(context, ref),
                icon: const Icon(Icons.add),
                label: Text(LocaleKeys.adminAddProduct.tr()),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...waiterProducts.map(
              (product) => Card(
                child: ListTile(
                  title: Text(localizedOrRaw(product.nameKey)),
                  subtitle: Text(
                    '${_categoryLabel(product)} · ${FormatUtils.currency(product.price)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: LocaleKeys.commonEdit.tr(),
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => showAdminProductEditor(
                          context,
                          ref,
                          product: product,
                        ),
                      ),
                      IconButton(
                        tooltip: LocaleKeys.commonRemove.tr(),
                        icon: const Icon(Icons.delete_outline),
                        color: AppColors.error,
                        onPressed: () async {
                          final confirm =
                              await showAdminDeleteConfirm(context);
                          if (confirm != true) return;
                          await ref
                              .read(adminProductsProvider.notifier)
                              .deleteProduct(product.id);
                        },
                      ),
                    ],
                  ),
                  onTap: () => showAdminProductEditor(
                    context,
                    ref,
                    product: product,
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

class AdminWaiterExtrasTab extends ConsumerWidget {
  const AdminWaiterExtrasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: Text(
            LocaleKeys.adminWaiterExtrasTabHint.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        const Expanded(
          child: AdminCatalogExtrasTab(showInlineAddButton: true),
        ),
      ],
    );
  }
}

class AdminWaiterSortTab extends ConsumerWidget {
  const AdminWaiterSortTab({
    super.key,
    required this.productOrder,
    required this.extraOrder,
    required this.onProductOrderChanged,
    required this.onExtraOrderChanged,
  });

  final List<String> productOrder;
  final List<String> extraOrder;
  final ValueChanged<List<String>> onProductOrderChanged;
  final ValueChanged<List<String>> onExtraOrderChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(adminProductsProvider).value ?? [];
    final extras = ref.watch(adminCatalogExtrasProvider).value ?? [];

    final waiterProducts = products
        .where(
          (p) =>
              p.category == ProductCategory.tost ||
              p.category == ProductCategory.sahanda ||
              p.category == ProductCategory.drink ||
              p.category == ProductCategory.snack ||
              p.isCombo ||
              p.category == ProductCategory.combo,
        )
        .toList();

    List<T> sortIds<T>(List<T> items, String Function(T) idFor, List<String> order) {
      if (order.isEmpty) return items;
      final indexOf = {for (var i = 0; i < order.length; i++) order[i]: i};
      return [...items]
        ..sort((a, b) {
          final ai = indexOf[idFor(a)];
          final bi = indexOf[idFor(b)];
          if (ai != null && bi != null) return ai.compareTo(bi);
          if (ai != null) return -1;
          if (bi != null) return 1;
          return idFor(a).compareTo(idFor(b));
        });
    }

    final sortedProducts = sortIds(waiterProducts, (p) => p.id, productOrder);
    final sortedExtras = sortIds(extras, (e) => e.id, extraOrder);

  final productIds = sortedProducts.map((p) => p.id).toList();
    final extraIds = sortedExtras.map((e) => e.id).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          LocaleKeys.adminWaiterSortTabHint.tr(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          LocaleKeys.adminWaiterSortProducts.tr(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: productIds.length,
          onReorder: (oldIndex, newIndex) {
            final updated = [...productIds];
            if (newIndex > oldIndex) newIndex -= 1;
            final item = updated.removeAt(oldIndex);
            updated.insert(newIndex, item);
            onProductOrderChanged(updated);
          },
          itemBuilder: (context, index) {
            final product = sortedProducts[index];
            return ListTile(
              key: ValueKey(product.id),
              leading: const Icon(Icons.drag_handle),
              title: Text(localizedOrRaw(product.nameKey)),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          LocaleKeys.adminWaiterSortExtras.tr(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: extraIds.length,
          onReorder: (oldIndex, newIndex) {
            final updated = [...extraIds];
            if (newIndex > oldIndex) newIndex -= 1;
            final item = updated.removeAt(oldIndex);
            updated.insert(newIndex, item);
            onExtraOrderChanged(updated);
          },
          itemBuilder: (context, index) {
            final extra = sortedExtras[index];
            return ListTile(
              key: ValueKey(extra.id),
              leading: const Icon(Icons.drag_handle),
              title: Text(localizedOrRaw(extra.name)),
            );
          },
        ),
      ],
    );
  }
}
