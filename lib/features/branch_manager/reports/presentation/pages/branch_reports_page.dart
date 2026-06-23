import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../presentation/widgets/branch_printer_settings_panel.dart';
import '../../../../../core/widgets/ops_analytics_panel.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';

class BranchReportsPage extends ConsumerWidget {
  const BranchReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(branchDailyStatsProvider);
    final analytics = ref.watch(branchOpsAnalyticsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.branchReportsTitle.tr()),
        actions: const [RoleLogoutAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _ReportCard(
            icon: Icons.attach_money,
            title: LocaleKeys.branchDailyRevenue.tr(),
            value: FormatUtils.currency(stats.revenue),
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          _ReportCard(
            icon: Icons.receipt_long,
            title: LocaleKeys.branchOrderCount.tr(),
            value: '${stats.count}',
            color: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.lg),
          const BranchPrinterSettingsPanel(),
          const SizedBox(height: AppSpacing.lg),
          OpsAnalyticsPanel(analytics: analytics),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            labelKey: LocaleKeys.authLogout,
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go(RoutePaths.authLogin);
            },
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.bodySmall),
              Text(value, style: Theme.of(context).textTheme.displayLarge),
            ],
          ),
        ],
      ),
    );
  }
}
