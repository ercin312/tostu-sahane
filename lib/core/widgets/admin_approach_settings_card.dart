import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_settings_provider.dart';
import '../localization/locale_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class AdminApproachSettingsCard extends ConsumerWidget {
  const AdminApproachSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final minutes = settings.deliveryApproachNotifyMinutes;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active_outlined,
                    color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    LocaleKeys.adminApproachNotifyTitle.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              LocaleKeys.adminApproachNotifyHint.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: minutes.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: LocaleKeys.orderAuditMinutes.tr(
                      namedArgs: {'minutes': '$minutes'},
                    ),
                    onChanged: (v) => ref
                        .read(appSettingsProvider.notifier)
                        .setApproachMinutes(v.round()),
                  ),
                ),
                Text(
                  LocaleKeys.orderAuditMinutes.tr(
                    namedArgs: {'minutes': '$minutes'},
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
