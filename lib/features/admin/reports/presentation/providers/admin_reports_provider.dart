import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/analytics/admin_reports_analytics.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../customer/home/presentation/providers/branch_provider.dart';

final adminReportPeriodProvider = StateProvider<AdminReportPeriod>(
  (ref) => AdminReportPeriod.last7Days,
);

final adminReportCustomRangeProvider = StateProvider<AdminReportDateRange>(
  (ref) => AdminReportDateRange.last7Days(),
);

/// null = tüm şubeler
final adminReportBranchFilterProvider = StateProvider<String?>(
  (ref) => null,
);

final adminDetailedReportsProvider = Provider<AdminReportSnapshot>((ref) {
  final period = ref.watch(adminReportPeriodProvider);
  final customRange = ref.watch(adminReportCustomRangeProvider);
  final branchIdFilter = ref.watch(adminReportBranchFilterProvider);
  final orders = ref.watch(ordersProvider).value ?? [];
  final branches = ref.watch(branchesProvider).value ?? [];
  return AdminReportsCalculator.compute(
    orders: orders,
    branches: branches,
    period: period,
    customRange: customRange,
    branchIdFilter: branchIdFilter,
  );
});
