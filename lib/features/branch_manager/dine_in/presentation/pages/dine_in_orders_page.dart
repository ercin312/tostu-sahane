import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../presentation/widgets/branch_order_list_tile.dart';
import '../widgets/dine_in_timeline_sidebar.dart';

/// Şube veya sistem yöneticisi için iç sipariş listesi.
class DineInOrdersPage extends ConsumerWidget {
  const DineInOrdersPage({
    super.key,
    required this.listProvider,
    this.showBranchName = false,
    this.embedded = false,
  });

  final Provider<List<Order>> listProvider;
  final bool showBranchName;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(listProvider);
    final body = orders.isEmpty
        ? Center(child: Text(LocaleKeys.dineInOrdersEmpty.tr()))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: Text(
                  LocaleKeys.branchOrderTapForDetail.tr(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: orders.length,
                  separatorBuilder: (_, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return DineInTimelineListTile(
                      order: order,
                      showConnector: index < orders.length - 1,
                      showBranchName: showBranchName,
                      onTap: () =>
                          showBranchOrderDetail(context, ref, order),
                    );
                  },
                ),
              ),
            ],
          );

    if (embedded) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.dineInOrdersTitle.tr()),
        actions: const [RoleLogoutAction()],
      ),
      body: body,
    );
  }
}
