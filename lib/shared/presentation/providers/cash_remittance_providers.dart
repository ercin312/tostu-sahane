import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../features/customer/home/presentation/providers/branch_provider.dart';
import '../../data/datasources/local/local_datasources.dart';
import '../../data/repositories/courier_cash_remittance_repository.dart';
import '../../data/repositories/courier_wallet_repository.dart';
import '../../domain/entities/courier_cash_remittance.dart';
import '../../domain/usecases/courier/courier_wallet_use_cases.dart';
import 'repository_providers.dart';

final courierCashRemittanceRepositoryProvider =
    Provider<CourierCashRemittanceRepository>((ref) {
  return CourierCashRemittanceRepository(
    firestore: ref.watch(firestoreDataSourceProvider),
    local: CourierCashRemittanceLocalDataSource(),
  );
});

final courierWalletRepositoryProvider = Provider<CourierWalletRepository>((ref) {
  return CourierWalletRepository(
    orders: ref.watch(orderRepositoryProvider),
    remittances: ref.watch(courierCashRemittanceRepositoryProvider),
  );
});

final getCourierWalletSummaryUseCaseProvider =
    Provider<GetCourierWalletSummaryUseCase>((ref) {
  return GetCourierWalletSummaryUseCase(
    ref.watch(courierWalletRepositoryProvider),
  );
});

final getCourierWalletHistoryUseCaseProvider =
    Provider<GetCourierWalletHistoryUseCase>((ref) {
  return GetCourierWalletHistoryUseCase(
    ref.watch(courierWalletRepositoryProvider),
  );
});

final requestCourierRemittanceUseCaseProvider =
    Provider<RequestCourierRemittanceUseCase>((ref) {
  return RequestCourierRemittanceUseCase(
    ref.watch(courierWalletRepositoryProvider),
  );
});

final branchCashRemittancesProvider =
    StreamProvider<List<CourierCashRemittance>>((ref) {
  final branch = ref.watch(managedBranchProvider).value;
  if (branch == null) return Stream.value([]);
  return ref
      .watch(courierCashRemittanceRepositoryProvider)
      .watchForBranch(branch.id);
});

final adminCashRemittancesProvider =
    StreamProvider<List<CourierCashRemittance>>((ref) {
  return ref.watch(courierCashRemittanceRepositoryProvider).watchAll();
});

final courierCashRemittancesProvider =
    StreamProvider<List<CourierCashRemittance>>((ref) {
  final auth = ref.watch(authProvider);
  if (auth == null) return Stream.value([]);
  return ref
      .watch(courierCashRemittanceRepositoryProvider)
      .watchForCourier(auth.user.id);
});

final branchPendingRemittanceCountProvider = Provider<int>((ref) {
  final remittances = ref.watch(branchCashRemittancesProvider).value ?? [];
  return remittances.where((r) => r.isPending).length;
});

final adminPendingRemittanceCountProvider = Provider<int>((ref) {
  final remittances = ref.watch(adminCashRemittancesProvider).value ?? [];
  return remittances.where((r) => r.isPending).length;
});
