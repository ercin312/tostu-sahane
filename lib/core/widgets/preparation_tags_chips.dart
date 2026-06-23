import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/waiter_preparation_tags.dart';

/// Hazırlık tercihi chip'leri — garson ve sipariş detaylarında ortak.
class PreparationTagsChips extends StatelessWidget {
  const PreparationTagsChips({
    super.key,
    required this.tags,
    this.compact = false,
  });

  final List<String> tags;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final tag in tags)
          Chip(
            visualDensity: compact ? VisualDensity.compact : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            labelPadding: compact
                ? const EdgeInsets.symmetric(horizontal: 4)
                : null,
            label: Text(
              WaiterPreparationTags.label(tag),
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
      ],
    );
  }
}
