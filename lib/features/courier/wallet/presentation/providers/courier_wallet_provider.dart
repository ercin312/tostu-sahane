import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/domain/entities/courier_wallet.dart';
import '../../../../../shared/presentation/providers/cash_remittance_providers.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';

final courierWalletSummaryProvider =
    FutureProvider<CourierWalletSummary>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth == null) {
    return const CourierWalletSummary(
      todayDeliveries: 0,
      todayCash: 0,
      todayCard: 0,
      availableBalance: 0,
      pendingPayout: 0,
      totalEarned: 0,
    );
  }
  ref.watch(ordersRefreshSignalProvider);
  ref.watch(courierCashRemittancesProvider);
  return ref
      .read(getCourierWalletSummaryUseCaseProvider)
      .call(auth.user.id);
});

final courierWalletHistoryProvider =
    FutureProvider<List<CourierWalletEntry>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth == null) return [];
  ref.watch(ordersRefreshSignalProvider);
  ref.watch(courierCashRemittancesProvider);
  return ref.read(getCourierWalletHistoryUseCaseProvider).call(auth.user.id);
});

final ordersRefreshSignalProvider = Provider<int>((ref) {
  ref.watch(ordersProvider);
  return DateTime.now().millisecondsSinceEpoch;
});
