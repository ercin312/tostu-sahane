import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../localization/locale_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/order_modifiers_utils.dart';
import '../utils/waiter_order_notes.dart';
import '../utils/order_status_utils.dart';
import 'order_cart_item_rows.dart';
import 'order_modifiers_panel.dart';
import 'order_preparation_preferences_panel.dart';
import '../../shared/domain/entities/order.dart';

/// Sipariş durum geçmişi ve zaman damgaları.
class OrderStatusTimeline extends StatelessWidget {
  const OrderStatusTimeline({
    super.key,
    required this.order,
    this.compact = false,
  });

  final Order order;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isCancelled = order.status == OrderStatus.cancelled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.orderStatusHistory.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (isCancelled) ...[
          _TimelineRow(
            label: OrderStatusUtils.label(OrderStatus.cancelled),
            at: order.atStatus(OrderStatus.cancelled),
            isCurrent: true,
            isPast: false,
            compact: compact,
            color: AppColors.error,
          ),
          if (!compact) const SizedBox(height: AppSpacing.xs),
        ],
        ...OrderStatusUtils.fulfillmentPipeline.map((status) {
          final at = order.atStatus(status);
          final isCurrent = !isCancelled && order.status == status;
          final isPast = !isCancelled &&
              OrderStatusUtils.isPastFulfillmentStep(status, order.status);
          if (at == null && !isCurrent && !isPast) {
            return const SizedBox.shrink();
          }
          return _TimelineRow(
            label: OrderStatusUtils.label(status),
            at: at,
            fallbackAt: status == OrderStatus.received ? order.createdAt : null,
            isCurrent: isCurrent,
            isPast: isPast,
            compact: compact,
          );
        }),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.isCurrent,
    required this.isPast,
    required this.compact,
    this.at,
    this.fallbackAt,
    this.color,
  });

  final String label;
  final DateTime? at;
  final DateTime? fallbackAt;
  final bool isCurrent;
  final bool isPast;
  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;
    final timestamp = at ?? fallbackAt;

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4 : AppSpacing.xs),
      child: Row(
        children: [
          Icon(
            isCurrent
                ? Icons.radio_button_checked
                : isPast
                    ? Icons.check_circle
                    : Icons.radio_button_off,
            size: compact ? 16 : 18,
            color: isPast || isCurrent ? activeColor : AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: color,
                      ),
                ),
                if (timestamp != null)
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OrderItemsDetail extends StatelessWidget {
  const OrderItemsDetail({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.orderItemsDetail.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.xs),
        OrderCartItemRows(items: order.items),
        if (OrderModifiersUtils.hasModifiers(order)) ...[
          const SizedBox(height: AppSpacing.sm),
          OrderModifiersPanel(order: order),
        ],
        if (WaiterOrderNotes.hasNote(order)) ...[
          const SizedBox(height: AppSpacing.sm),
          OrderPreparationPreferencesPanel(order: order),
        ],
        if (!order.isDineIn) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            order.address,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
