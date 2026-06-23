import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/media/app_image.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../shared/domain/entities/product_extra.dart';
import '../../../presentation/providers/admin_provider.dart';

class AdminProductExtraPicker extends ConsumerWidget {
  const AdminProductExtraPicker({
    super.key,
    required this.selectedIds,
    required this.onChanged,
  });

  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;

  void _toggle(String id) {
    final next = Set<String>.of(selectedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(adminCatalogExtrasProvider);

    return catalogAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Text(LocaleKeys.commonError.tr()),
      data: (catalog) {
        if (catalog.isEmpty) {
          return Text(
            LocaleKeys.adminNoCatalogExtras.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              LocaleKeys.adminSelectProductExtras.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              LocaleKeys.adminSelectProductExtrasHint.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...catalog.map(
              (extra) => _CatalogExtraCheckboxTile(
                extra: extra,
                selected: selectedIds.contains(extra.id),
                onTap: () => _toggle(extra.id),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CatalogExtraCheckboxTile extends StatelessWidget {
  const _CatalogExtraCheckboxTile({
    required this.extra,
    required this.selected,
    required this.onTap,
  });

  final ProductExtra extra;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = localizedOrRaw(extra.name);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.06)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.divider,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: extra.imageUrl != null && extra.imageUrl!.isNotEmpty
                        ? AppImage(
                            source: extra.imageUrl,
                            fit: BoxFit.cover,
                          )
                        : ColoredBox(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            child: Icon(
                              Icons.fastfood_outlined,
                              color: AppColors.primary.withValues(alpha: 0.5),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        FormatUtils.currency(extra.price),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: selected,
                  onChanged: (_) => onTap(),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
