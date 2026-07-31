import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../core/widgets/role_logout_action.dart';
import '../../../../shared/presentation/providers/cash_remittance_providers.dart';
import '../../../customer/product_detail/presentation/providers/product_reviews_provider.dart';
import '../config/admin_nav_config.dart';
import '../providers/admin_provider.dart';

/// Tostu Şahane Yönetim + yönetim araçları (anasayfadan ayrı sekme).
class AdminToolsPage extends ConsumerWidget {
  const AdminToolsPage({super.key});

  int _badgeCount(WidgetRef ref, AdminNavBadge? badge) {
    return switch (badge) {
      AdminNavBadge.remittances =>
        ref.watch(adminPendingRemittanceCountProvider),
      AdminNavBadge.reviews => ref.watch(adminPendingReviewCountProvider),
      null => 0,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminReportsProvider);
    final branches = ref.watch(adminBranchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.adminToolsTitle.tr()),
        actions: const [RoleLogoutAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const AppLogo(height: 48),
          const SizedBox(height: AppSpacing.md),
          Text(
            LocaleKeys.adminWelcome.tr(),
            style: Theme.of(context).textTheme.displayLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            LocaleKeys.adminToolsSubtitle.tr(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          reports.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (report) => Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _OverviewCard(
                        title: LocaleKeys.adminTotalRevenue.tr(),
                        value: FormatUtils.currency(report.totalRevenue),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _OverviewCard(
                        title: LocaleKeys.adminTotalOrders.tr(),
                        value: '${report.totalOrders}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _OverviewCard(
                  title: LocaleKeys.adminActiveBranches.tr(),
                  value: '${branches.value?.length ?? report.activeBranches}',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            LocaleKeys.adminToolsTitle.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          // Telefon asistanı eğitimi — Windows'ta ilk sırada belirgin kart
          Card(
            color: AppColors.primary.withValues(alpha: 0.06),
            child: ListTile(
              leading: const Icon(
                Icons.record_voice_over,
                color: AppColors.primary,
              ),
              title: Text(
                LocaleKeys.navPhoneAiTraining.tr(),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(LocaleKeys.adminPhoneAiTrainingSubtitle.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(RoutePaths.adminPhoneAiTraining),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final item in AdminNavConfig.mobileToolsItems)
            if (item.route != RoutePaths.adminPhoneAiTraining)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Card(
                  child: ListTile(
                    leading: _leadingIcon(
                      item,
                      _badgeCount(ref, item.badge),
                    ),
                    title: Text(item.labelKey.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(item.route),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _leadingIcon(AdminNavItem item, int count) {
    final icon = Icon(item.filledIcon, color: AppColors.primary);
    if (count <= 0) return icon;
    return Badge(
      isLabelVisible: true,
      label: Text('$count'),
      child: icon,
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
