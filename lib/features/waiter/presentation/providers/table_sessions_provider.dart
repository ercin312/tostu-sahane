import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/waiter_mode_settings.dart';
import '../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../../customer/home/presentation/providers/branch_provider.dart';
import '../../domain/table_session.dart';

final branchTableSessionsProvider = Provider<List<TableSession>>((ref) {
  final branch = ref.watch(managedBranchProvider).value;
  if (branch == null) return const [];

  final tableCount =
      ref.watch(waiterModeSettingsProvider).valueOrNull?.tableCount ??
          WaiterModeSettings.defaults.tableCount;
  final orders = ref.watch(ordersProvider).value ?? [];

  return buildTableSessions(
    tableCount: tableCount,
    branchId: branch.id,
    orders: orders,
  );
});

final tableSessionProvider = Provider.family<TableSession?, int>((ref, table) {
  final sessions = ref.watch(branchTableSessionsProvider);
  if (table < 1 || table > sessions.length) return null;
  return sessions[table - 1];
});
