import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/orders/order_workflow.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/printing/order_receipt_printer.dart';
import '../../../../../core/widgets/order_status_timeline.dart';
import '../../../../../core/utils/order_status_utils.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../core/widgets/order_audit_detail_panel.dart';
import '../../../../../shared/domain/entities/user.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class BranchOrderCard extends ConsumerStatefulWidget {
  const BranchOrderCard({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<BranchOrderCard> createState() => _BranchOrderCardState();
}

class _BranchOrderCardState extends ConsumerState<BranchOrderCard> {
  Order get order => widget.order;

  @override
  Widget build(BuildContext context) {
    final isNew = order.status == OrderStatus.received;
    final auth = ref.watch(authProvider);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNew
            ? BorderSide(color: AppColors.warning.withValues(alpha: 0.7), width: 2)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
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
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (isNew)
                  Chip(
                    label: Text(
                      LocaleKeys.branchNewOrderBadge.tr(),
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                  ),
              ],
            ),
            Text(order.customerName),
            Text(
              OrderStatusUtils.label(order.status),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              LocaleKeys.orderReceivedAt.tr(
                namedArgs: {
                  'time': DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt),
                },
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (order.atStatus(order.status) != null &&
                order.status != OrderStatus.received)
              Text(
                LocaleKeys.orderStatusUpdatedAt.tr(
                  namedArgs: {
                    'time': DateFormat('dd.MM.yyyy HH:mm')
                        .format(order.atStatus(order.status)!),
                  },
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            if (!order.deliveryNow && order.scheduledAt != null)
              Text(
                LocaleKeys.orderScheduledAt.tr(
                  namedArgs: {
                    'datetime': DateFormat('dd.MM.yyyy HH:mm')
                        .format(order.scheduledAt!),
                  },
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
              ),
            Text(FormatUtils.currency(order.totalAmount)),
            const SizedBox(height: AppSpacing.md),
            OrderAuditDetailPanel(order: order),
            const SizedBox(height: AppSpacing.md),
            OrderStatusTimeline(order: order, compact: true),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            const SizedBox(height: AppSpacing.sm),
            OrderItemsDetail(order: order),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                if (auth != null) ..._actionButtons(context, ref, auth.user),
                OutlinedButton.icon(
                  onPressed: () =>
                      OrderReceiptPrinter.printReceipt(context, order),
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: Text(LocaleKeys.receiptPrint.tr()),
                ),
                TextButton.icon(
                  onPressed: () => OrderReceiptPrinter.shareReceipt(order),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: Text(LocaleKeys.receiptShare.tr()),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _actionButtons(
    BuildContext context,
    WidgetRef ref,
    User user,
  ) {
    final actions = <Widget>[];

    if (OrderWorkflow.canPerform(user, order, OrderWorkflowAction.accept)) {
      actions.add(
        ElevatedButton(
          onPressed: () => _runAction(
            context,
            ref,
            OrderWorkflowAction.accept,
            successMessage: LocaleKeys.branchOrderAccepted.tr(),
          ),
          child: Text(LocaleKeys.branchAcceptOrder.tr()),
        ),
      );
    }

    if (OrderWorkflow.canPerform(user, order, OrderWorkflowAction.markReady)) {
      actions.add(
        ElevatedButton(
          onPressed: () => _runAction(
            context,
            ref,
            OrderWorkflowAction.markReady,
            successMessage: LocaleKeys.branchOrderReady.tr(),
          ),
          child: Text(LocaleKeys.branchMarkReady.tr()),
        ),
      );
    }

    if (OrderWorkflow.canPerform(user, order, OrderWorkflowAction.reject)) {
      actions.add(
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
          onPressed: () => _rejectOrder(context, ref, user),
          child: Text(LocaleKeys.branchRejectOrder.tr()),
        ),
      );
    }

    if (order.status == OrderStatus.waitingCourier &&
        (user.role == UserRole.branchManager ||
            user.role == UserRole.branchStaff ||
            user.role == UserRole.superAdmin)) {
      actions.add(
        Chip(
          label: Text(LocaleKeys.branchWaitingCourierAccept.tr()),
          backgroundColor: AppColors.warning.withValues(alpha: 0.15),
        ),
      );
    }

    return actions;
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    OrderWorkflowAction action, {
    required String successMessage,
  }) async {
    try {
      await ref
          .read(ordersProvider.notifier)
          .performWorkflowAction(order.id, action);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    }
  }

  Future<void> _rejectOrder(
    BuildContext context,
    WidgetRef ref,
    User user,
  ) async {
    if (!OrderWorkflow.canPerform(user, order, OrderWorkflowAction.reject)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.branchRejectOrder.tr()),
        content: Text(LocaleKeys.branchRejectOrderConfirm.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(LocaleKeys.commonOk.tr()),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await _runAction(
        context,
        ref,
        OrderWorkflowAction.reject,
        successMessage: LocaleKeys.branchOrderRejected.tr(),
      );
    }
  }
}
