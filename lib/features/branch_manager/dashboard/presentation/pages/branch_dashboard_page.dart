import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/presentation/providers/cash_remittance_providers.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../customer/home/presentation/providers/branch_provider.dart';
import '../../../dine_in/presentation/widgets/dine_in_timeline_sidebar.dart';
import '../../../presentation/widgets/branch_order_list_tile.dart';
import '../../../presentation/widgets/pulsing_alert_banner.dart';

class BranchDashboardPage extends ConsumerWidget {
  const BranchDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(branchOrdersProvider);
    final stats = ref.watch(branchDailyStatsProvider);
    final branch = ref.watch(managedBranchProvider).value;
    final newOrders =
        orders.where((o) => o.status == OrderStatus.received).toList();

    final pendingRemittances = ref.watch(branchPendingRemittanceCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.branchDashboardTitle.tr()),
        actions: const [RoleLogoutAction()],
      ),
      body: DashboardWithDineInSidebar(
        child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (branch != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text(
                LocaleKeys.branchAssignedLabel.tr(
                  namedArgs: {'name': branch.name},
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (newOrders.isNotEmpty)
            PulsingAlertBanner(
              message: LocaleKeys.branchNewOrderAlert.tr(
                namedArgs: {'count': '${newOrders.length}'},
              ),
            ),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: LocaleKeys.branchDailyRevenue.tr(),
                  value: FormatUtils.currency(stats.revenue),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  title: LocaleKeys.branchOrderCount.tr(),
                  value: '${stats.count}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            child: ListTile(
              leading: Badge(
                isLabelVisible: pendingRemittances > 0,
                label: Text('$pendingRemittances'),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.primary,
                ),
              ),
              title: Text(LocaleKeys.cashRemittanceBranchCardTitle.tr()),
              subtitle: Text(LocaleKeys.cashRemittanceBranchCardHint.tr()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(RoutePaths.branchCashRemittances),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            LocaleKeys.branchOrdersTitle.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          Text(
            LocaleKeys.branchOrderTapForDetail.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (orders.isEmpty)
            Text(LocaleKeys.branchNoOrders.tr())
          else
            ...orders.map(
              (order) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: BranchOrderListTile(
                  order: order,
                  onTap: () => showBranchOrderDetail(context, ref, order),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
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
