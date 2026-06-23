import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/delivery_eta_utils.dart';
import '../../../../../core/utils/order_status_utils.dart';
import '../../../../customer/home/presentation/providers/branch_provider.dart';
import '../../../../../core/widgets/app_logo.dart';
import '../../../../../core/widgets/live_delivery_map_view.dart';
import '../../../../../core/widgets/order_status_timeline.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';

class OrderTrackingPage extends ConsumerStatefulWidget {
  const OrderTrackingPage({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends ConsumerState<OrderTrackingPage> {
  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);
    final order = ref.watch(orderByIdProvider(widget.orderId));

    return ordersAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(LocaleKeys.commonError.tr())),
      ),
      data: (_) {
        if (order == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(LocaleKeys.commonError.tr())),
          );
        }
        return _TrackingView(orderId: widget.orderId);
      },
    );
  }
}

class _TrackingView extends ConsumerStatefulWidget {
  const _TrackingView({required this.orderId});

  final String orderId;

  @override
  ConsumerState<_TrackingView> createState() => _TrackingViewState();
}

class _TrackingViewState extends ConsumerState<_TrackingView>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _courierController;
  late final AnimationController _deliveredController;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _courierSlide;
  late final Animation<double> _deliveredScale;
  Timer? _refreshTimer;

  Order? get _order => ref.watch(orderByIdProvider(widget.orderId));

  bool get _showLiveCourierMap {
    final order = _order;
    if (order == null) return false;
    return order.status == OrderStatus.waitingCourier ||
        order.status == OrderStatus.onTheWay;
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _courierController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _deliveredController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _courierSlide = Tween<double>(begin: -0.08, end: 0.08).animate(
      CurvedAnimation(parent: _courierController, curve: Curves.easeInOut),
    );
    _deliveredScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _deliveredController, curve: Curves.elasticOut),
    );

    if (_order?.status == OrderStatus.delivered) {
      _deliveredController.forward();
    }
    _syncRefreshTimer();
  }

  @override
  void didUpdateWidget(covariant _TrackingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final order = _order;
    if (order == null) return;
    if (order.status == OrderStatus.delivered) {
      _deliveredController.forward(from: 0);
    }
    _syncRefreshTimer();
  }

  void _syncRefreshTimer() {
    final order = _order;
    if (order == null || !OrderStatusUtils.isInFulfillment(order.status)) {
      _refreshTimer?.cancel();
      _refreshTimer = null;
      return;
    }
    _refreshTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(ordersProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _courierController.dispose();
    _deliveredController.dispose();
    super.dispose();
  }

  int _currentStep(Order order) =>
      OrderStatusUtils.fulfillmentStepIndex(order.status);

  double _progress(Order order) {
    final step = _currentStep(order);
    if (step < 0) return 0;
    return (step + 1) / OrderStatusUtils.fulfillmentPipeline.length;
  }

  int _etaMinutes(Order order) {
    final branches = ref.watch(branchesProvider).value ?? [];
    final branch =
        branches.where((b) => b.id == order.branchId).firstOrNull;
    if (branch == null) {
      return order.estimatedDeliveryMinutes ?? 25;
    }
    return DeliveryEtaUtils.remainingMinutes(order: order, branch: branch);
  }

  IconData _stepIcon(int index) {
    return switch (index) {
      0 => Icons.receipt_long_rounded,
      1 => Icons.restaurant_rounded,
      2 => Icons.delivery_dining_rounded,
      3 => Icons.two_wheeler_rounded,
      _ => Icons.check_circle_rounded,
    };
  }

  DateTime? _timestampForStep(Order order, int index) {
    if (index < 0 || index >= OrderStatusUtils.fulfillmentPipeline.length) {
      return null;
    }
    final status = OrderStatusUtils.fulfillmentPipeline[index];
    return order.atStatus(status) ??
        (status == OrderStatus.received ? order.createdAt : null);
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (order.status == OrderStatus.cancelled) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            LocaleKeys.orderNumber.tr(
              namedArgs: {'number': '${order.orderNumber}'},
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cancel_outlined, size: 72, color: AppColors.error),
                const SizedBox(height: AppSpacing.md),
                Text(
                  LocaleKeys.orderStatusCancelled.tr(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  LocaleKeys.orderCancelledMessage.tr(),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isDelivered = order.status == OrderStatus.delivered;
    final isOnTheWay = order.status == OrderStatus.onTheWay;
    final duration = order.deliveryDurationMinutes;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.orderNumber.tr(
            namedArgs: {'number': '${order.orderNumber}'},
          ),
        ),
      ),
      body: Column(
        children: [
          _ProgressHeader(
            progress: _progress(order),
            etaMinutes: _etaMinutes(order),
            isDelivered: isDelivered,
            receivedAt: order.createdAt,
          ),
          if (_showLiveCourierMap)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: _OrderTrackingMap(order: order),
            ),
          if (isOnTheWay)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: AnimatedBuilder(
                animation: _courierSlide,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_courierSlide.value * 120, 0),
                    child: child,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.two_wheeler, color: AppColors.primary, size: 32),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocaleKeys.orderTrackingOnTheWay.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(color: AppColors.primary),
                            ),
                            if (order.courierName != null)
                              Text(
                                LocaleKeys.orderTrackingCourierName.tr(
                                  namedArgs: {'name': order.courierName!},
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (duration != null && isDelivered)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Text(
                LocaleKeys.deliveryDurationMinutes.tr(
                  namedArgs: {'minutes': '$duration'},
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                ...List.generate(OrderStatusUtils.fulfillmentPipeline.length,
                    (index) {
                  final currentStep = _currentStep(order);
                  final isCompleted =
                      currentStep >= 0 && index <= currentStep;
                  final isActive =
                      index == currentStep && !isDelivered;
                  return _AnimatedTrackingStep(
                    label: OrderStatusUtils.allStepKeys[index].tr(),
                    icon: _stepIcon(index),
                    isCompleted: isCompleted,
                    isActive: isActive,
                    isLast: index ==
                        OrderStatusUtils.fulfillmentPipeline.length - 1,
                    pulseAnimation: isActive ? _pulseAnimation : null,
                    deliveredScale: index == currentStep && isDelivered
                        ? _deliveredScale
                        : null,
                    timestamp: _timestampForStep(order, index),
                  );
                }),
                const SizedBox(height: AppSpacing.lg),
                const Divider(),
                const SizedBox(height: AppSpacing.sm),
                OrderItemsDetail(order: order),
                if (order.canCustomerCancel) ...[
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: () => _cancelOrder(context),
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(LocaleKeys.orderCancel.tr()),
                  ),
                ],
                if (order.rating != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      order.rating!,
                      (_) => const Icon(Icons.star, color: Colors.amber),
                    ),
                  ),
                  if (order.ratingComment != null)
                    Text(
                      order.ratingComment!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.orderCancel.tr()),
        content: Text(LocaleKeys.orderCancelConfirm.tr()),
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
      await ref.read(ordersProvider.notifier).cancelOrder(widget.orderId);
    }
  }
}

class _OrderTrackingMap extends ConsumerWidget {
  const _OrderTrackingMap({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);

    return branchesAsync.when(
      loading: () => const SizedBox(
        height: 260,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (branches) {
        if (branches.isEmpty) return const SizedBox.shrink();

        final branch = branches.firstWhere(
          (b) => b.id == order.branchId,
          orElse: () => branches.first,
        );
        final deliveryLat =
            order.deliveryLatitude ?? branch.latitude + 0.012;
        final deliveryLng =
            order.deliveryLongitude ?? branch.longitude + 0.008;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleKeys.orderTrackingMapTitle.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            LiveDeliveryMapView(
              branchLat: branch.latitude,
              branchLng: branch.longitude,
              deliveryLat: deliveryLat,
              deliveryLng: deliveryLng,
              courierLat: order.courierLatitude,
              courierLng: order.courierLongitude,
              height: 240,
              animateCourier: order.status == OrderStatus.onTheWay,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        );
      },
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({
    required this.progress,
    required this.etaMinutes,
    required this.isDelivered,
    required this.receivedAt,
  });

  final double progress;
  final int etaMinutes;
  final bool isDelivered;
  final DateTime receivedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppLogo(height: 32),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isDelivered
                      ? LocaleKeys.orderTrackingDelivered.tr()
                      : LocaleKeys.orderTrackingEta.tr(
                          namedArgs: {'minutes': '$etaMinutes'},
                        ),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            LocaleKeys.orderReceivedAt.tr(
              namedArgs: {
                'time': DateFormat('dd.MM.yyyy HH:mm').format(receivedAt),
              },
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: AppColors.divider,
                  color: AppColors.primary,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedTrackingStep extends StatelessWidget {
  const _AnimatedTrackingStep({
    required this.label,
    required this.icon,
    required this.isCompleted,
    required this.isActive,
    required this.isLast,
    this.pulseAnimation,
    this.deliveredScale,
    this.timestamp,
  });

  final String label;
  final IconData icon;
  final bool isCompleted;
  final bool isActive;
  final bool isLast;
  final Animation<double>? pulseAnimation;
  final Animation<double>? deliveredScale;
  final DateTime? timestamp;

  @override
  Widget build(BuildContext context) {
    final lineColor =
        isCompleted ? AppColors.primary : AppColors.divider;

    Widget node = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted ? AppColors.primary : AppColors.white,
        border: Border.all(
          color: isActive ? AppColors.primary : lineColor,
          width: isActive ? 3 : 2,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Icon(
        isCompleted ? Icons.check : icon,
        size: 18,
        color: isCompleted ? AppColors.white : AppColors.textSecondary,
      ),
    );

    if (pulseAnimation != null) {
      node = AnimatedBuilder(
        animation: pulseAnimation!,
        builder: (context, child) =>
            Transform.scale(scale: pulseAnimation!.value, child: child),
        child: node,
      );
    }

    if (deliveredScale != null) {
      node = ScaleTransition(scale: deliveredScale!, child: node);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              node,
              if (!isLast)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    width: 3,
                    color: lineColor,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg, top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: isActive || isCompleted
                              ? AppColors.primary
                              : AppColors.textPrimary,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.w500,
                        ),
                    child: Text(label),
                  ),
                  if (timestamp != null)
                    Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(timestamp!),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
