import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/widgets/admin_approach_settings_card.dart';
import '../../../../../core/widgets/admin_operational_data_purge_panel.dart';
import '../../../../../core/widgets/admin_reports_dashboard.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../presentation/providers/admin_provider.dart';
import '../providers/admin_reports_provider.dart';

class AdminReportsPage extends ConsumerWidget {
  const AdminReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminReportsProvider);
    final snapshot = ref.watch(adminDetailedReportsProvider);
    final period = ref.watch(adminReportPeriodProvider);
    final customRange = ref.watch(adminReportCustomRangeProvider);
    final branchFilter = ref.watch(adminReportBranchFilterProvider);
    final branchList = ref.watch(adminBranchesProvider).value ?? [];
    final branchOptions = branchList
        .map((branch) => (id: branch.id, name: branch.name))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(LocaleKeys.adminReportsTitle.tr()),
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: const [RoleLogoutAction()],
      ),
      body: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
        data: (report) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(adminReportsProvider);
            await ref.read(ordersProvider.notifier).refresh();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: AdminReportsDashboard(
                  snapshot: snapshot,
                  period: period,
                  customRange: customRange,
                  branches: branchOptions,
                  selectedBranchId: branchFilter,
                  onBranchChanged: (value) => ref
                      .read(adminReportBranchFilterProvider.notifier)
                      .state = value,
                  activeBranches: branchFilter == null
                      ? report.activeBranches
                      : 1,
                  onPeriodChanged: (value) => ref
                      .read(adminReportPeriodProvider.notifier)
                      .state = value,
                  onCustomRangeChanged: (range) => ref
                      .read(adminReportCustomRangeProvider.notifier)
                      .state = range,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        LocaleKeys.adminReportsSettings.tr(),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      const AdminApproachSettingsCard(),
                      const SizedBox(height: 24),
                      const AdminOperationalDataPurgePanel(),
                    ],
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
