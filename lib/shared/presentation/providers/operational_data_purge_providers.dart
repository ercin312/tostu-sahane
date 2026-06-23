import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/local/local_datasources.dart';
import '../../data/repositories/operational_data_purge_repository.dart';
import '../../domain/entities/operational_purge_result.dart';
import '../../../features/admin/presentation/providers/admin_provider.dart';
import '../../../features/admin/reports/presentation/providers/admin_reports_provider.dart';
import '../../../features/customer/product_detail/presentation/providers/product_reviews_provider.dart';
import 'cash_remittance_providers.dart';
import 'orders_provider.dart';
import 'repository_providers.dart';

final operationalDataPurgeRepositoryProvider =
    Provider<OperationalDataPurgeRepository>((ref) {
  return OperationalDataPurgeRepository(
    firestore: ref.watch(firestoreDataSourceProvider),
    mock: ref.watch(mockApiDataSourceProvider),
    orderLocal: OrderLocalDataSource(),
    remittanceLocal: CourierCashRemittanceLocalDataSource(),
  );
});

Future<void> refreshAfterOperationalPurge(WidgetRef ref) async {
  ref.invalidate(adminReportsProvider);
  ref.invalidate(adminDetailedReportsProvider);
  ref.invalidate(pendingProductReviewsProvider);
  ref.invalidate(customerProductReviewsProvider);
  ref.invalidate(branchCashRemittancesProvider);
  ref.invalidate(adminCashRemittancesProvider);
  ref.invalidate(courierCashRemittancesProvider);
  await ref.read(ordersProvider.notifier).refresh();
}

Future<OperationalPurgeResult> purgeAllReportData(WidgetRef ref) async {
  final result =
      await ref.read(operationalDataPurgeRepositoryProvider).purgeAllReportData();
  await refreshAfterOperationalPurge(ref);
  return result;
}

Future<OperationalPurgeResult> purgeCourierOperationalData(
  WidgetRef ref,
  String courierId,
) async {
  final result = await ref
      .read(operationalDataPurgeRepositoryProvider)
      .purgeCourierData(courierId);
  await refreshAfterOperationalPurge(ref);
  return result;
}

Future<OperationalPurgeResult> purgeBranchOperationalData(
  WidgetRef ref,
  String branchId,
) async {
  final result = await ref
      .read(operationalDataPurgeRepositoryProvider)
      .purgeBranchData(branchId);
  await refreshAfterOperationalPurge(ref);
  return result;
}
