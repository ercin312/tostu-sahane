import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/widgets/role_logout_action.dart';import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../presentation/widgets/branch_order_list_view.dart';

class BranchOrdersPage extends ConsumerWidget {
  const BranchOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeOrders = ref.watch(branchOrdersProvider);
    final historyOrders = ref.watch(branchHistoryOrdersProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(LocaleKeys.branchOrdersTitle.tr()),
          actions: const [RoleLogoutAction()],
          bottom: TabBar(
            tabs: [
              Tab(text: LocaleKeys.branchOrdersActive.tr()),
              Tab(text: LocaleKeys.branchOrdersHistory.tr()),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OrdersList(
              orders: activeOrders,
              emptyMessage: LocaleKeys.branchNoOrders.tr(),
            ),
            _OrdersList(
              orders: historyOrders,
              emptyMessage: LocaleKeys.branchNoHistoryOrders.tr(),
              showNewBadge: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({
    required this.orders,
    required this.emptyMessage,
    this.showNewBadge = true,
  });

  final List<Order> orders;
  final String emptyMessage;
  final bool showNewBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BranchOrderListView(
      orders: orders,
      emptyMessage: emptyMessage,
      showNewBadge: showNewBadge,
    );
  }
}
