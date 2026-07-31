import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/order_status_utils.dart';
import '../../../../../core/utils/waiter_order_notes.dart';
import '../../../../../core/widgets/order_preparation_preferences_panel.dart';
import '../../../../../shared/domain/entities/order.dart';
import 'branch_order_detail_panel.dart';

/// Sipariş listesinde kompakt satır — tıklanınca detay açılır.
class BranchOrderListTile extends StatelessWidget {
  const BranchOrderListTile({
    super.key,
    required this.order,
    required this.onTap,
    this.showNewBadge = true,
  });

  final Order order;
  final VoidCallback onTap;
  final bool showNewBadge;

  @override
  Widget build(BuildContext context) {
    final isNew = showNewBadge && order.status == OrderStatus.received;
    final statusColor = switch (order.status) {
      OrderStatus.cancelled => AppColors.error,
      OrderStatus.delivered => AppColors.success,
      OrderStatus.received => AppColors.warning,
      OrderStatus.ready => AppColors.success,
      _ => AppColors.primary,
    };

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: order.phoneFailed
                  ? AppColors.error.withValues(alpha: 0.7)
                  : isNew
                      ? AppColors.warning.withValues(alpha: 0.6)
                      : AppColors.divider.withValues(alpha: 0.8),
              width: order.phoneFailed || isNew ? 2 : 1,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: statusColor.withValues(alpha: 0.12),
                child: Icon(
                  Icons.receipt_long,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            LocaleKeys.orderNumber.tr(
                              namedArgs: {'number': '${order.orderNumber}'},
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (order.isPhoneOrder)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: (order.phoneFailed
                                      ? AppColors.error
                                      : AppColors.primary)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              order.phoneFailed
                                  ? LocaleKeys.branchPhoneOrderFailedBadge.tr()
                                  : order.phoneIncomplete
                                      ? LocaleKeys
                                          .branchPhoneOrderIncompleteBadge
                                          .tr()
                                      : LocaleKeys.branchPhoneOrderBadge.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: order.phoneFailed
                                        ? AppColors.error
                                        : AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        if (isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              LocaleKeys.branchNewOrderBadge.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${order.customerName} · ${OrderStatusUtils.labelFor(order)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (order.isPhoneOrder &&
                        (order.customerPhone?.trim().isNotEmpty ?? false))
                      Text(
                        order.customerPhone!.trim(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: order.phoneFailed
                                  ? AppColors.error
                                  : AppColors.textSecondary,
                              fontWeight: order.phoneFailed
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      FormatUtils.dateTimeTr(order.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    if (order.phoneStatusInquiry) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Text(
                          order.phoneStatusInquiryNote?.trim().isNotEmpty == true
                              ? order.phoneStatusInquiryNote!.trim()
                              : LocaleKeys.branchPhoneOrderInquiryDefault.tr(),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                    ],
                    if (order.phoneFailed) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          (order.orderNote?.trim().isNotEmpty ?? false)
                              ? order.orderNote!.trim()
                              : LocaleKeys.branchPhoneOrderFailedNote.tr(),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                    ] else if (WaiterOrderNotes.hasNote(order)) ...[
                      const SizedBox(height: 6),
                      OrderPreparationPreferencesPanel(
                        order: order,
                        inline: true,
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    FormatUtils.currency(order.totalAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showBranchOrderDetail(
  BuildContext context,
  WidgetRef ref,
  Order order,
) {
  final wide = MediaQuery.sizeOf(context).width >= 720;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: BranchOrderDetailPanel(order: order),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (_, controller) => BranchOrderDetailPanel(
        order: order,
        scrollController: controller,
      ),
    ),
  );
}
