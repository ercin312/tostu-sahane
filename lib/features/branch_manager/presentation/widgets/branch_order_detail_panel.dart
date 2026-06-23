import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/orders/order_workflow.dart';
import '../../../../../core/printing/order_receipt_printer.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/order_status_utils.dart';
import '../../../../../core/widgets/order_audit_detail_panel.dart';
import '../../../../../core/widgets/order_status_timeline.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/domain/entities/user.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class BranchOrderDetailPanel extends ConsumerStatefulWidget {
  const BranchOrderDetailPanel({
    super.key,
    required this.order,
    this.scrollController,
  });

  final Order order;
  final ScrollController? scrollController;

  @override
  ConsumerState<BranchOrderDetailPanel> createState() =>
      _BranchOrderDetailPanelState();
}

class _BranchOrderDetailPanelState extends ConsumerState<BranchOrderDetailPanel> {
  Order _currentOrder(List<Order> orders) {
    for (final o in orders) {
      if (o.id == widget.order.id) return o;
    }
    return widget.order;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final orders = ref.watch(ordersProvider).value ?? [];
    final order = _currentOrder(orders);
    final isNew = order.status == OrderStatus.received;

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: widget.scrollController != null
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(child: _buildContent(context, auth, order, isNew)),
              ],
            )
          : _buildContent(context, auth, order, isNew),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AuthState? auth,
    Order order,
    bool isNew,
  ) {
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      LocaleKeys.orderNumber.tr(
                        namedArgs: {'number': '${order.orderNumber}'},
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  if (isNew)
                    Chip(
                      label: Text(LocaleKeys.branchNewOrderBadge.tr()),
                      backgroundColor: AppColors.warning.withValues(alpha: 0.15),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(order.customerName,
                  style: Theme.of(context).textTheme.titleMedium),
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
                    'time':
                        DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt),
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
                ),
              Text(
                FormatUtils.currency(order.totalAmount),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
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
                  if (auth != null) ..._actionButtons(context, ref, auth.user, order),
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
    );
  }

  List<Widget> _actionButtons(
    BuildContext context,
    WidgetRef ref,
    User user,
    Order order,
  ) {
    final actions = <Widget>[];

    if (OrderWorkflow.canPerform(user, order, OrderWorkflowAction.accept)) {
      actions.add(
        ElevatedButton(
          onPressed: () => _runAction(
            context,
            ref,
            order,
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
            order,
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
          onPressed: () => _rejectOrder(context, ref, user, order),
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
    Order order,
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
    Order order,
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
        order,
        OrderWorkflowAction.reject,
        successMessage: LocaleKeys.branchOrderRejected.tr(),
      );
    }
  }
}
