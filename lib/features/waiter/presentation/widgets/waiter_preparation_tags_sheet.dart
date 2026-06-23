import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/waiter_preparation_tags.dart';
import '../../../../core/widgets/preparation_tags_chips.dart';

Future<Set<String>> showWaiterPreparationTagsSheet(
  BuildContext context, {
  required Set<String> selected,
}) async {
  final result = await showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    builder: (context) => _WaiterPreparationTagsSheet(initial: selected),
  );
  return result ?? selected;
}

class _WaiterPreparationTagsSheet extends StatefulWidget {
  const _WaiterPreparationTagsSheet({required this.initial});

  final Set<String> initial;

  @override
  State<_WaiterPreparationTagsSheet> createState() =>
      _WaiterPreparationTagsSheetState();
}

class _WaiterPreparationTagsSheetState extends State<_WaiterPreparationTagsSheet> {
  late Set<String> _selected = Set<String>.from(widget.initial);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              LocaleKeys.waiterPrepSheetTitle.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text(
              LocaleKeys.waiterPrepSheetSubtitle.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final key in WaiterPreparationTags.allKeys)
                  FilterChip(
                    label: Text(
                      WaiterPreparationTags.label(key),
                      style: const TextStyle(fontSize: 13),
                    ),
                    visualDensity: VisualDensity.compact,
                    selected: _selected.contains(key),
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _selected.add(key);
                        } else {
                          _selected.remove(key);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(_selected.clear),
                child: Text(LocaleKeys.waiterPrepClear.tr()),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: Text(
                  LocaleKeys.commonOk.tr(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaiterPreparationTagsChips extends StatelessWidget {
  const WaiterPreparationTagsChips({
    super.key,
    required this.tags,
    this.compact = false,
  });

  final List<String> tags;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PreparationTagsChips(tags: tags, compact: compact);
  }
}
