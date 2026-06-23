import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../customer/home/presentation/providers/branch_provider.dart';
import '../../../presentation/providers/admin_provider.dart';

class AdminWaiterProductPricesPanel extends ConsumerStatefulWidget {
  const AdminWaiterProductPricesPanel({
    super.key,
    required this.initialProductPrices,
    required this.initialCatalogExtraPrices,
    required this.onProductPricesChanged,
    required this.onCatalogExtraPricesChanged,
  });

  final Map<String, double> initialProductPrices;
  final Map<String, double> initialCatalogExtraPrices;
  final ValueChanged<Map<String, double>> onProductPricesChanged;
  final ValueChanged<Map<String, double>> onCatalogExtraPricesChanged;

  @override
  ConsumerState<AdminWaiterProductPricesPanel> createState() =>
      _AdminWaiterProductPricesPanelState();
}

class _AdminWaiterProductPricesPanelState
    extends ConsumerState<AdminWaiterProductPricesPanel> {
  final _productControllers = <String, TextEditingController>{};
  final _extraControllers = <String, TextEditingController>{};
  final _productPriceOverrides = <String, double>{};
  final _catalogExtraPriceOverrides = <String, double>{};
  var _initialized = false;

  @override
  void dispose() {
    for (final controller in _productControllers.values) {
      controller.dispose();
    }
    for (final controller in _extraControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _ensureInitialized() {
    if (_initialized) return;
    _initialized = true;
    _productPriceOverrides.addAll(widget.initialProductPrices);
    _catalogExtraPriceOverrides.addAll(widget.initialCatalogExtraPrices);
    for (final entry in widget.initialProductPrices.entries) {
      _productControllers[entry.key] = TextEditingController(
        text: _formatPrice(entry.value),
      );
    }
    for (final entry in widget.initialCatalogExtraPrices.entries) {
      _extraControllers[entry.key] = TextEditingController(
        text: _formatPrice(entry.value),
      );
    }
  }

  TextEditingController _controllerFor(
    Map<String, TextEditingController> map,
    String id,
  ) {
    return map.putIfAbsent(id, TextEditingController.new);
  }

  String _formatPrice(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  void _onProductFieldChanged(String id, String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed == null || raw.trim().isEmpty) {
      _productPriceOverrides.remove(id);
    } else if (parsed >= 0) {
      _productPriceOverrides[id] = parsed;
    }
    widget.onProductPricesChanged(Map.from(_productPriceOverrides));
  }

  void _onExtraFieldChanged(String id, String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed == null || raw.trim().isEmpty) {
      _catalogExtraPriceOverrides.remove(id);
    } else if (parsed >= 0) {
      _catalogExtraPriceOverrides[id] = parsed;
    }
    widget.onCatalogExtraPricesChanged(Map.from(_catalogExtraPriceOverrides));
  }

  @override
  Widget build(BuildContext context) {
    _ensureInitialized();
    final productsAsync = ref.watch(adminProductsProvider);
    final extrasAsync = ref.watch(catalogExtrasProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              LocaleKeys.adminWaiterProductPricesTitle.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              LocaleKeys.adminWaiterProductPricesSubtitle.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            productsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text(LocaleKeys.commonError.tr()),
              data: (products) {
                final sorted = [...products]
                  ..sort((a, b) => localizedOrRaw(a.nameKey)
                      .compareTo(localizedOrRaw(b.nameKey)));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      LocaleKeys.adminWaiterMenuPricesSection.tr(),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...sorted.map(
                      (product) => _PriceRow(
                        title: localizedOrRaw(product.nameKey),
                        catalogPrice: product.price,
                        controller: _controllerFor(
                          _productControllers,
                          product.id,
                        ),
                        onChanged: (value) =>
                            _onProductFieldChanged(product.id, value),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            extrasAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (extras) {
                if (extras.isEmpty) return const SizedBox.shrink();
                final sorted = [...extras]
                  ..sort((a, b) => localizedOrRaw(a.name)
                      .compareTo(localizedOrRaw(b.name)));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      LocaleKeys.adminWaiterCatalogExtrasPricesSection.tr(),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...sorted.map(
                      (extra) => _PriceRow(
                        title: localizedOrRaw(extra.name),
                        catalogPrice: extra.price,
                        controller: _controllerFor(
                          _extraControllers,
                          extra.id,
                        ),
                        onChanged: (value) =>
                            _onExtraFieldChanged(extra.id, value),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.title,
    required this.catalogPrice,
    required this.controller,
    required this.onChanged,
  });

  final String title;
  final double catalogPrice;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  LocaleKeys.adminWaiterProductPricesMobilePrice.tr(
                    namedArgs: {
                      'price': FormatUtils.currency(catalogPrice),
                    },
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            flex: 2,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: LocaleKeys.adminWaiterProductPricesWaiterPrice.tr(),
                hintText: LocaleKeys.adminWaiterProductPricesHint.tr(
                  namedArgs: {
                    'price': FormatUtils.currency(catalogPrice),
                  },
                ),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
