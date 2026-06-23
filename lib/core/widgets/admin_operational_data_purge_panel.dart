import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/locale_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../../shared/presentation/providers/operational_data_purge_providers.dart';
import 'operational_data_purge_dialog.dart';

class AdminOperationalDataPurgePanel extends ConsumerStatefulWidget {
  const AdminOperationalDataPurgePanel({super.key});

  @override
  ConsumerState<AdminOperationalDataPurgePanel> createState() =>
      _AdminOperationalDataPurgePanelState();
}

class _AdminOperationalDataPurgePanelState
    extends ConsumerState<AdminOperationalDataPurgePanel> {
  var _loading = false;

  Future<void> _purgeAll() async {
    final confirmed = await showOperationalDataPurgeDialog(
      context: context,
      title: LocaleKeys.opsDataPurgeAllTitle.tr(),
      description: LocaleKeys.opsDataPurgeAllDescription.tr(),
    );
    if (!confirmed || !mounted) return;

    setState(() => _loading = true);
    try {
      final result = await purgeAllReportData(ref);
      if (mounted) {
        showOperationalPurgeSuccessSnackBar(
          context,
          orders: result.ordersDeleted,
          reviews: result.reviewsDeleted,
          remittances: result.remittancesDeleted,
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          leading: Icon(
            Icons.cleaning_services_outlined,
            color: AppColors.textSecondary.withValues(alpha: 0.8),
          ),
          title: Text(
            LocaleKeys.opsDataPurgeSectionTitle.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          subtitle: Text(
            LocaleKeys.opsDataPurgeSectionHint.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                LocaleKeys.opsDataPurgeAllDescription.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
              ),
              onPressed: _loading ? null : _purgeAll,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: Text(LocaleKeys.opsDataPurgeAllTitle.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
