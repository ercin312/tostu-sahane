import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/order_modifiers_utils.dart';
import '../../../../../core/utils/waiter_order_notes.dart';
import '../../../../../core/widgets/order_modifiers_panel.dart';
import '../../../../../core/widgets/order_preparation_preferences_panel.dart';
import '../../../../../shared/data/mock/mock_data.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/domain/entities/user.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../customer/home/presentation/providers/branch_provider.dart';
import '../../../presentation/widgets/branch_order_list_tile.dart';

class DineInTimelineSidebar extends ConsumerWidget {
  const DineInTimelineSidebar({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(dashboardDineInOrdersProvider);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border(
          left: BorderSide(color: AppColors.divider.withValues(alpha: 0.8)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    LocaleKeys.dineInOrdersTitle.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (!compact)
                  IconButton(
                    tooltip: LocaleKeys.dineInOrdersTitle.tr(),
                    onPressed: () => context.go(RoutePaths.branchDineIn),
                    icon: const Icon(Icons.open_in_full, size: 20),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: orders.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        LocaleKeys.dineInOrdersEmpty.tr(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: orders.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.xs),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      final isLast = index == orders.length - 1;
                      return DineInTimelineListTile(
                        order: order,
                        showConnector: !isLast,
                        compact: compact,
                        showBranchName: ref.watch(authProvider)?.user.role ==
                            UserRole.superAdmin,
                        onTap: () =>
                            showBranchOrderDetail(context, ref, order),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class DashboardWithDineInSidebar extends ConsumerWidget {
  const DashboardWithDineInSidebar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 960) return child;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: child),
        SizedBox(
          width: width >= 1280 ? 320 : 280,
          child: const DineInTimelineSidebar(),
        ),
      ],
    );
  }
}

class DineInTimelineListTile extends ConsumerWidget {
  const DineInTimelineListTile({
    super.key,
    required this.order,
    required this.showConnector,
    this.compact = false,
    this.showBranchName = false,
    this.onTap,
  });

  final Order order;
  final bool showConnector;
  final bool compact;
  final bool showBranchName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final time = DateFormat('HH:mm').format(order.createdAt);
    final itemLines = [
      for (final item in order.items)
        OrderModifiersUtils.itemSummaryLine(item, MockData.catalogExtras),
    ];
    final hasPrefs = WaiterOrderNotes.hasNote(order);

    final branchName = showBranchName
        ? ref.watch(branchesProvider).value
            ?.where((b) => b.id == order.branchId)
            .map((b) => b.name)
            .firstOrNull
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.divider,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: EdgeInsets.all(compact ? 10 : AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            LocaleKeys.dineInTableLabel.tr(
                              namedArgs: {
                                'table': '${order.tableNumber ?? '-'}',
                              },
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Text(
                          time,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    if (branchName != null) ...[
                      Text(
                        branchName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 2),
                    ],
                    Text(
                      LocaleKeys.dineInWaiterLabel.tr(
                        namedArgs: {
                          'name': order.waiterCode ?? order.waiterName ?? '—',
                        },
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A${order.orderNumber} · ${FormatUtils.currency(order.totalAmount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 4),
                      if (itemLines.isNotEmpty)
                        Text(
                          itemLines.join(' · '),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      if (hasPrefs) ...[
                        const SizedBox(height: 6),
                        OrderPreparationPreferencesPanel(
                          order: order,
                          compact: true,
                        ),
                      ],
                    ] else ...[
                      if (itemLines.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          itemLines.join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                      if (hasPrefs) ...[
                        const SizedBox(height: 4),
                        OrderPreparationPreferencesPanel(
                          order: order,
                          inline: true,
                        ),
                      ],
                    ],
                    if (!compact && OrderModifiersUtils.hasModifiers(order)) ...[
                      const SizedBox(height: 6),
                      OrderModifiersPanel(order: order, compact: true),
                    ],
                    if (onTap != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            LocaleKeys.branchOrderTapForDetail.tr(),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
  }
}
