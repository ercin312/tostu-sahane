import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../localization/locale_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/order_status_utils.dart';
import '../utils/payment_method_utils.dart';
import '../../shared/domain/entities/order.dart';

/// Şube/yönetici için sipariş denetim özeti: durum, kurye, onaylayan, ödeme, süreler.
class OrderAuditDetailPanel extends StatelessWidget {
  const OrderAuditDetailPanel({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textSecondary,
        );
    final valueStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.orderAuditTitle.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (order.isDineIn) ...[
            if (order.tableNumber != null)
              _row(
                LocaleKeys.dineInTableField.tr(),
                '${order.tableNumber}',
                textStyle,
                valueStyle,
              ),
            if (order.waiterName != null || order.waiterCode != null)
              _row(
                LocaleKeys.dineInWaiterField.tr(),
                order.waiterCode ?? order.waiterName ?? '—',
                textStyle,
                valueStyle,
              ),
          ],
          _row(
            LocaleKeys.orderAuditStatus.tr(),
            OrderStatusUtils.label(order.status),
            textStyle,
            valueStyle,
          ),
          _row(
            LocaleKeys.orderAuditPayment.tr(),
            PaymentMethodUtils.label(order.paymentMethod),
            textStyle,
            valueStyle,
          ),
          if (order.courierName != null)
            _row(
              LocaleKeys.orderAuditCourier.tr(),
              order.courierName!,
              textStyle,
              valueStyle,
            ),
          if (order.actorNameFor(OrderStatus.preparing) != null)
            _row(
              LocaleKeys.orderAuditApprovedBy.tr(),
              order.actorNameFor(OrderStatus.preparing)!,
              textStyle,
              valueStyle,
            ),
          if (order.actorNameFor(OrderStatus.cancelled) != null)
            _row(
              LocaleKeys.orderAuditCancelledBy.tr(),
              order.actorNameFor(OrderStatus.cancelled)!,
              textStyle,
              valueStyle,
            ),
          if (order.deliveryDurationMinutes != null)
            _row(
              LocaleKeys.orderAuditDeliveryDuration.tr(),
              LocaleKeys.orderAuditMinutes.tr(
                namedArgs: {'minutes': '${order.deliveryDurationMinutes}'},
              ),
              textStyle,
              valueStyle,
            ),
          if (order.totalFulfillmentMinutes != null)
            _row(
              LocaleKeys.orderAuditTotalDuration.tr(),
              LocaleKeys.orderAuditMinutes.tr(
                namedArgs: {'minutes': '${order.totalFulfillmentMinutes}'},
              ),
              textStyle,
              valueStyle,
            ),
          _row(
            LocaleKeys.orderAuditTotal.tr(),
            FormatUtils.currency(order.totalAmount),
            textStyle,
            valueStyle,
          ),
          if (order.status == OrderStatus.delivered)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppColors.success),
                  const SizedBox(width: 4),
                  Text(
                    LocaleKeys.orderAuditDelivered.tr(),
                    style: valueStyle?.copyWith(color: AppColors.success),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(
    String label,
    String value,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: labelStyle)),
          Expanded(flex: 3, child: Text(value, style: valueStyle)),
        ],
      ),
    );
  }
}
