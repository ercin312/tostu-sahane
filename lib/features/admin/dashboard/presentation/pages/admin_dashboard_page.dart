import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/daily_order_stats_header.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../branch_manager/dine_in/presentation/widgets/dine_in_timeline_sidebar.dart';
import '../../../../branch_manager/presentation/widgets/branch_order_list_tile.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../branch_manager/presentation/widgets/pulsing_alert_banner.dart';
import '../../../../customer/product_detail/presentation/providers/product_reviews_provider.dart';

/// Anasayfa = siparişler (üstte bugünün cirosu / sipariş). Yönetim araçları ayrı sekmede.
class AdminDashboardPage extends ConsumerWidget {
  const AdminDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentOrders = ref.watch(branchOrdersProvider);
    final stats = ref.watch(adminDailyStatsProvider);
    final pendingReviews = ref.watch(adminPendingReviewCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.adminRecentOrders.tr()),
        actions: const [RoleLogoutAction()],
      ),
      body: DashboardWithDineInSidebar(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DailyOrderStatsHeader(
              revenue: stats.revenue,
              orderCount: stats.count,
            ),
            if (pendingReviews > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: GestureDetector(
                  onTap: () => context.go(RoutePaths.adminPendingReviews),
                  child: PulsingAlertBanner(
                    icon: Icons.rate_review_outlined,
                    message: LocaleKeys.adminPendingReviewsAlert.tr(
                      namedArgs: {'count': '$pendingReviews'},
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text(
                LocaleKeys.branchOrderTapForDetail.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
            Expanded(
              child: recentOrders.isEmpty
                  ? Center(child: Text(LocaleKeys.branchNoOrders.tr()))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.lg,
                      ),
                      itemCount: recentOrders.length,
                      itemBuilder: (context, index) {
                        final order = recentOrders[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: BranchOrderListTile(
                            order: order,
                            showNewBadge: false,
                            onTap: () =>
                                showBranchOrderDetail(context, ref, order),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
