import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../shared/data/mock/mock_data.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../cart/presentation/utils/branch_cart_guard.dart';
import '../../../home/presentation/providers/branch_provider.dart';

bool customerCanReorder(Order order) {
  return order.status == OrderStatus.delivered ||
      order.status == OrderStatus.cancelled;
}

Future<void> reorderCustomerOrder(
  BuildContext context,
  WidgetRef ref,
  Order order,
) async {
  if (!customerCanReorder(order) || order.items.isEmpty) return;

  final branches = ref.read(branchesProvider).value ?? MockData.branches;
  final branch = branches.firstWhere(
    (b) => b.id == order.branchId,
    orElse: () => branches.first,
  );

  final currentBranch = ref.read(branchProvider).value;
  if (currentBranch?.id != branch.id) {
    await selectBranchWithCartGuard(context, ref, branch);
    if (!context.mounted) return;
  } else if (ref.read(cartProvider).isNotEmpty &&
      ref.read(cartBranchIdProvider) != branch.id) {
    await selectBranchWithCartGuard(context, ref, branch);
    if (!context.mounted) return;
  }

  ref.read(cartProvider.notifier).reorderItems(
        order.items,
        branchId: order.branchId,
      );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(LocaleKeys.reorderAddedToCart.tr())),
  );
  context.push(RoutePaths.customerCart);
}
