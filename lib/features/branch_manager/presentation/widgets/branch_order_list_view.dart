import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../shared/domain/entities/order.dart';
import 'branch_order_list_tile.dart';

/// Kompakt sipariş listesi — satıra tıklayınca detay açılır.
class BranchOrderListView extends ConsumerWidget {
  const BranchOrderListView({
    super.key,
    required this.orders,
    this.emptyMessage,
    this.showNewBadge = true,
  });

  final List<Order> orders;
  final String? emptyMessage;
  final bool showNewBadge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return Center(
        child: Text(emptyMessage ?? LocaleKeys.branchNoOrders.tr()),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final order = orders[index];
        return BranchOrderListTile(
          order: order,
          showNewBadge: showNewBadge,
          onTap: () => showBranchOrderDetail(context, ref, order),
        );
      },
    );
  }
}
