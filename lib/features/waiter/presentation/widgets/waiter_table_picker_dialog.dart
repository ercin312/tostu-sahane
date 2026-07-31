import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/domain/entities/waiter_mode_settings.dart';
import '../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../providers/table_sessions_provider.dart';

/// Dokunmatik masa seçici — klavye yok, sadece büyük numara butonları.
Future<int?> showWaiterTablePicker(
  BuildContext context, {
  required String title,
  String? subtitle,
  int? excludeTable,
  int? highlightTable,
}) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => _WaiterTablePickerDialog(
      title: title,
      subtitle: subtitle,
      excludeTable: excludeTable,
      highlightTable: highlightTable,
    ),
  );
}

class _WaiterTablePickerDialog extends ConsumerWidget {
  const _WaiterTablePickerDialog({
    required this.title,
    this.subtitle,
    this.excludeTable,
    this.highlightTable,
  });

  final String title;
  final String? subtitle;
  final int? excludeTable;
  final int? highlightTable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tableCount =
        ref.watch(waiterModeSettingsProvider).valueOrNull?.tableCount ??
            WaiterModeSettings.defaults.tableCount;
    final sessions = ref.watch(branchTableSessionsProvider);
    final size = MediaQuery.sizeOf(context);
    final maxH = size.height * 0.85;
    final maxW = size.width * (size.width >= 600 ? 0.7 : 0.94);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cols = constraints.maxWidth >= 720
                        ? 8
                        : constraints.maxWidth >= 520
                            ? 6
                            : constraints.maxWidth >= 380
                                ? 5
                                : 4;
                    return GridView.builder(
                      itemCount: tableCount,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.15,
                      ),
                      itemBuilder: (context, index) {
                        final n = index + 1;
                        final excluded = excludeTable == n;
                        final session = sessions
                            .where((s) => s.tableNumber == n)
                            .firstOrNull;
                        final isOpen = session?.isOpen ?? false;
                        final selected = highlightTable == n;

                        Color bg = const Color(0xFFE8EDF3);
                        Color fg = AppColors.textPrimary;
                        if (selected) {
                          bg = AppColors.success;
                          fg = Colors.white;
                        } else if (isOpen) {
                          bg = const Color(0xFFFFE8A3);
                        }
                        if (excluded) {
                          bg = AppColors.divider;
                          fg = AppColors.textSecondary;
                        }

                        return Material(
                          color: bg,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            onTap: excluded
                                ? null
                                : () => Navigator.pop(context, n),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.success
                                      : const Color(0xFF9AA7B5),
                                  width: selected ? 2.5 : 1,
                                ),
                              ),
                              child: Text(
                                '$n',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: fg,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(LocaleKeys.commonCancel.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
