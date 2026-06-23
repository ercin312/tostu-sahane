import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/orders/order_workflow.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/maps_navigation_utils.dart';
import '../../../../../core/utils/order_status_utils.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';

class CourierTasksPage extends ConsumerWidget {
  const CourierTasksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myTasks = ref.watch(courierOrdersProvider);
    final available = ref.watch(waitingCourierOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.courierTasksTitle.tr()),
        actions: const [RoleLogoutAction()],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            LocaleKeys.courierActiveTasks.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (myTasks.isEmpty && available.isEmpty)
            Text(LocaleKeys.courierNoTasks.tr())
          else ...[
            ...myTasks.map(
              (order) => _CourierTaskCard(order: order, isAssigned: true),
            ),
            ...available.map(
              (order) => _CourierTaskCard(order: order, isAssigned: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _CourierTaskCard extends ConsumerStatefulWidget {
  const _CourierTaskCard({
    required this.order,
    required this.isAssigned,
  });

  final Order order;
  final bool isAssigned;

  @override
  ConsumerState<_CourierTaskCard> createState() => _CourierTaskCardState();
}

class _CourierTaskCardState extends ConsumerState<_CourierTaskCard> {
  bool _busy = false;

  Order get order => widget.order;

  Future<void> _openNavigation() async {
    await MapsNavigationUtils.openNavigation(
      address: order.address,
      latitude: order.deliveryLatitude,
      longitude: order.deliveryLongitude,
    );
  }

  Future<void> _runAction(OrderWorkflowAction action) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(ordersProvider.notifier)
          .performWorkflowAction(order.id, action);
      if (!mounted) return;
      final message = switch (action) {
        OrderWorkflowAction.assignCourier =>
          LocaleKeys.courierTaskAccepted.tr(),
        OrderWorkflowAction.markDelivered =>
          LocaleKeys.courierDeliveredSuccess.tr(),
        _ => LocaleKeys.commonOk,
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message.tr())),
      );
      if (action == OrderWorkflowAction.assignCourier) {
        await _openNavigation();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth?.user;
    final canAccept = user != null &&
        OrderWorkflow.canPerform(
          user,
          order,
          OrderWorkflowAction.assignCourier,
        );
    final canDeliver = user != null &&
        OrderWorkflow.canPerform(
          user,
          order,
          OrderWorkflowAction.markDelivered,
        );

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.orderNumber.tr(
                namedArgs: {'number': '${order.orderNumber}'},
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(OrderStatusUtils.label(order.status)),
            Text(order.address),
            if (order.deliveryLatitude != null)
              Text(
                LocaleKeys.orderDeliveryCoords.tr(
                  namedArgs: {
                    'lat': order.deliveryLatitude!.toStringAsFixed(5),
                    'lng': order.deliveryLongitude!.toStringAsFixed(5),
                  },
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            Text(FormatUtils.currency(order.totalAmount)),
            const SizedBox(height: AppSpacing.sm),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.sm),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  if (!widget.isAssigned && canAccept)
                    ElevatedButton(
                      onPressed: () =>
                          _runAction(OrderWorkflowAction.assignCourier),
                      child: Text(LocaleKeys.courierAcceptAndNavigate.tr()),
                    ),
                  if (widget.isAssigned) ...[
                    ElevatedButton.icon(
                      onPressed: _openNavigation,
                      icon: const Icon(Icons.navigation),
                      label: Text(LocaleKeys.courierNavigate.tr()),
                    ),
                    if (canDeliver)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                        ),
                        onPressed: () =>
                            _runAction(OrderWorkflowAction.markDelivered),
                        child: Text(LocaleKeys.courierMarkDelivered.tr()),
                      ),
                  ],
                  OutlinedButton.icon(
                    onPressed: () =>
                        context.push(RoutePaths.courierOrderMap(order.id)),
                    icon: const Icon(Icons.map_outlined),
                    label: Text(LocaleKeys.courierOpenInAppMap.tr()),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
