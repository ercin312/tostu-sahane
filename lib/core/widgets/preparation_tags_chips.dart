import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../utils/waiter_preparation_tags.dart';
import '../../shared/presentation/providers/waiter_mode_settings_provider.dart';

/// Hazırlık tercihi chip'leri — garson ve sipariş detaylarında ortak.
class PreparationTagsChips extends ConsumerWidget {
  const PreparationTagsChips({
    super.key,
    required this.tags,
    this.compact = false,
  });

  final List<String> tags;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final settings = ref.watch(waiterModeSettingsProvider).valueOrNull;
    final options = settings?.preparationOptions;

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
              WaiterPreparationTags.label(tag, options: options),
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
