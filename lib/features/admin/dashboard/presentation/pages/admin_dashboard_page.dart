import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/widgets/app_logo.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../branch_manager/dine_in/presentation/widgets/dine_in_timeline_sidebar.dart';
import '../../../../branch_manager/presentation/widgets/branch_order_list_tile.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../branch_manager/presentation/widgets/pulsing_alert_banner.dart';
import '../../../../customer/product_detail/presentation/providers/product_reviews_provider.dart';
import '../../../presentation/widgets/admin_quick_links_section.dart';
import '../../../presentation/providers/admin_provider.dart';

class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminReportsProvider);
    final branches = ref.watch(adminBranchesProvider);
    final recentOrders = ref.watch(ordersProvider).value ?? [];

    final pendingReviews = ref.watch(adminPendingReviewCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.adminDashboardTitle.tr()),
        actions: const [RoleLogoutAction()],
      ),
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(LocaleKeys.commonError.tr())),
        data: (report) => DashboardWithDineInSidebar(
          child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            const AppLogo(height: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              LocaleKeys.adminWelcome.tr(),
              style: Theme.of(context).textTheme.displayLarge,
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: _AdminStatCard(
                    title: LocaleKeys.adminTotalRevenue.tr(),
                    value: FormatUtils.currency(report.totalRevenue),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _AdminStatCard(
                    title: LocaleKeys.adminTotalOrders.tr(),
                    value: '${report.totalOrders}',
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _AdminStatCard(
              title: LocaleKeys.adminActiveBranches.tr(),
              value: '${branches.value?.length ?? report.activeBranches}',
              color: AppColors.warning,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (pendingReviews > 0)
              GestureDetector(
                onTap: () => context.go(RoutePaths.adminPendingReviews),
                child: PulsingAlertBanner(
                  icon: Icons.rate_review_outlined,
                  message: LocaleKeys.adminPendingReviewsAlert.tr(
                    namedArgs: {'count': '$pendingReviews'},
                  ),
                ),
              ),
            if (pendingReviews > 0) const SizedBox(height: AppSpacing.sm),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.table_restaurant,
                  color: AppColors.primary,
                ),
                title: Text(LocaleKeys.dineInOrdersTitle.tr()),
                subtitle: Text(LocaleKeys.branchOrderTapForDetail.tr()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(RoutePaths.adminDineIn),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bar_chart, color: AppColors.primary),
                title: Text(LocaleKeys.adminReportsTitle.tr()),
                subtitle: Text(LocaleKeys.navReports.tr()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(RoutePaths.adminReports),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const AdminQuickLinksSection(),
            const SizedBox(height: AppSpacing.lg),
            Text(
              LocaleKeys.adminRecentOrders.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              LocaleKeys.branchOrderTapForDetail.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (recentOrders.isEmpty)
              Text(LocaleKeys.branchNoOrders.tr())
            else
              ...recentOrders.take(10).map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: BranchOrderListTile(
                        order: order,
                        showNewBadge: false,
                        onTap: () =>
                            showBranchOrderDetail(context, ref, order),
                      ),
                    ),
                  ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.title,
    required this.value,
    required this.color,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
