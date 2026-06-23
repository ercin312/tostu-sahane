import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/domain/entities/waiter_mode_settings.dart';
import '../../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../../../customer/home/presentation/providers/branch_provider.dart';
import '../../../../waiter/domain/table_session.dart';
import '../../../../waiter/presentation/providers/table_sessions_provider.dart';
import '../../../../waiter/presentation/widgets/waiter_table_chip.dart';
import '../../../dine_in/presentation/pages/dine_in_orders_page.dart';

/// Windows kasa ekranı — açık masalar ve ödeme, garson siparişleri listesi.
class BranchCashierPage extends ConsumerWidget {
  const BranchCashierPage({
    super.key,
    required this.listProvider,
    required this.billPathBuilder,
    this.showBranchName = false,
  });

  final Provider<List<Order>> listProvider;
  final String Function(int tableNumber) billPathBuilder;
  final bool showBranchName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(LocaleKeys.cashierTitle.tr()),
          toolbarHeight: 48,
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.table_restaurant_outlined, size: 20),
                text: LocaleKeys.cashierTablesTab.tr(),
              ),
              Tab(
                icon: const Icon(Icons.receipt_long_outlined, size: 20),
                text: LocaleKeys.cashierOrdersTab.tr(),
              ),
            ],
          ),
          actions: const [RoleLogoutAction()],
        ),
        body: TabBarView(
          children: [
            _CashierTablesTab(billPathBuilder: billPathBuilder),
            DineInOrdersPage(
              listProvider: listProvider,
              showBranchName: showBranchName,
              embedded: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _CashierTablesTab extends ConsumerWidget {
  const _CashierTablesTab({required this.billPathBuilder});

  final String Function(int tableNumber) billPathBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(managedBranchProvider).value;
    final tableCount =
        ref.watch(waiterModeSettingsProvider).valueOrNull?.tableCount ??
            WaiterModeSettings.defaults.tableCount;
    final sessions = ref.watch(branchTableSessionsProvider);
    final openCount = sessions.where((s) => s.isOpen).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        const hPad = AppSpacing.sm;
        const gridSpacing = 6.0;
        final width = constraints.maxWidth - hPad * 2;
        final crossAxisCount = width >= 720
            ? 8
            : width >= 540
                ? 6
                : width >= 400
                    ? 5
                    : 4;
        final rowCount = (tableCount + crossAxisCount - 1) ~/ crossAxisCount;
        final headerBlock = branch != null ? 72.0 : 52.0;
        final gridHeight = (constraints.maxHeight -
                headerBlock -
                gridSpacing * (rowCount - 1))
            .clamp(120.0, double.infinity);
        final cellWidth =
            (width - gridSpacing * (crossAxisCount - 1)) / crossAxisCount;
        final cellHeight = gridHeight / rowCount;
        final aspectRatio = (cellWidth / cellHeight).clamp(0.85, 1.6);

        return Padding(
          padding: const EdgeInsets.fromLTRB(hPad, AppSpacing.xs, hPad, hPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (branch != null)
                Text(
                  LocaleKeys.branchAssignedLabel.tr(
                    namedArgs: {'name': branch.name},
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              Text(
                LocaleKeys.cashierTablesHint.tr(
                  namedArgs: {'count': '$openCount'},
                ),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: gridSpacing,
                    crossAxisSpacing: gridSpacing,
                    childAspectRatio: aspectRatio,
                  ),
                  itemCount: tableCount,
                  itemBuilder: (context, index) {
                    final tableNumber = index + 1;
                    final session = index < sessions.length
                        ? sessions[index]
                        : TableSession(
                            tableNumber: tableNumber,
                            openOrders: const [],
                          );
                    return WaiterTableChip(
                      label: '$tableNumber',
                      compact: true,
                      isOpen: session.isOpen,
                      totalAmount:
                          session.isOpen ? session.totalAmount : null,
                      onTap: () {
                        if (!session.isOpen) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(LocaleKeys.cashierEmptyTable.tr()),
                            ),
                          );
                          return;
                        }
                        context.push(billPathBuilder(tableNumber));
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
