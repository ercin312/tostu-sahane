import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../shared/domain/entities/order.dart';
import '../localization/locale_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/waiter_order_notes.dart';
import 'preparation_tags_chips.dart';

/// Sipariş düzeyinde hazırlık tercihleri ve serbest not — tüm rollerde ortak.
class OrderPreparationPreferencesPanel extends StatelessWidget {
  const OrderPreparationPreferencesPanel({
    super.key,
    required this.order,
    this.compact = false,
    this.inline = false,
  });

  final Order order;
  final bool compact;
  /// Liste satırında kutu olmadan chip + not özeti.
  final bool inline;

  @override
  Widget build(BuildContext context) {
    if (!WaiterOrderNotes.hasNote(order)) {
      return const SizedBox.shrink();
    }

    final tags = order.preparationTags;
    final textNote = order.orderNote?.trim();

    if (inline) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tags.isNotEmpty) PreparationTagsChips(tags: tags, compact: true),
          if (textNote != null && textNote.isNotEmpty) ...[
            if (tags.isNotEmpty) const SizedBox(height: 4),
            Text(
              textNote,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.orderModifiersPrep.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
          ),
          if (tags.isNotEmpty) ...[
            SizedBox(height: compact ? 4 : AppSpacing.xs),
            PreparationTagsChips(tags: tags, compact: compact),
          ],
          if (textNote != null && textNote.isNotEmpty) ...[
            SizedBox(height: compact ? 4 : AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.sticky_note_2_outlined,
                  size: compact ? 14 : 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    textNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
