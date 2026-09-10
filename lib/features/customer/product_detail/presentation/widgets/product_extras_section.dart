import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../shared/domain/entities/product_extra.dart';

/// Yemeksepeti tarzı ekstra malzeme listesi (checkbox + ad + fiyat).
class ProductExtrasSection extends StatefulWidget {
  const ProductExtrasSection({
    super.key,
    required this.extras,
    required this.selectedIds,
    required this.onToggle,
    this.title,
    this.subtitle,
    this.initiallyExpanded = true,
  });

  final List<ProductExtra> extras;
  final Set<String> selectedIds;
  final ValueChanged<ProductExtra> onToggle;
  final String? title;
  final String? subtitle;
  final bool initiallyExpanded;

  @override
  State<ProductExtrasSection> createState() => _ProductExtrasSectionState();
}

class _ProductExtrasSectionState extends State<ProductExtrasSection> {
  late var _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (widget.extras.isEmpty) return const SizedBox.shrink();

    final title = widget.title ?? LocaleKeys.customerExtrasTitle.tr();
    final subtitle = widget.subtitle;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ...widget.extras.map(
              (extra) => _ExtraCheckRow(
                extra: extra,
                selected: widget.selectedIds.contains(extra.id),
                onTap: () => widget.onToggle(extra),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExtraCheckRow extends StatelessWidget {
  const _ExtraCheckRow({
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
    final priceLabel = extra.price > 0
        ? '+${FormatUtils.currency(extra.price)}'
        : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: AppColors.divider, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            if (priceLabel != null)
              Text(
                priceLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
