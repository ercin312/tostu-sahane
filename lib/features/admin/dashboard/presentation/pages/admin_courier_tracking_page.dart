import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/order_status_utils.dart';
import '../../../../../core/widgets/osm_tile_map_view.dart';
import '../../../../../features/customer/home/presentation/providers/branch_provider.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';

class AdminCourierTrackingPage extends ConsumerStatefulWidget {
  const AdminCourierTrackingPage({super.key});

  @override
  ConsumerState<AdminCourierTrackingPage> createState() =>
      _AdminCourierTrackingPageState();
}

class _AdminCourierTrackingPageState
    extends ConsumerState<AdminCourierTrackingPage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      ref.read(ordersProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deliveries = ref.watch(activeDeliveryOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.adminCourierTrackingTitle.tr()),
      ),
      body: deliveries.isEmpty
          ? Center(child: Text(LocaleKeys.adminCourierTrackingEmpty.tr()))
          : RefreshIndicator(
              onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  SizedBox(
                    height: 320,
                    child: _AdminCourierMap(orders: deliveries),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    LocaleKeys.adminCourierTrackingList.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...deliveries.map((o) => _DeliveryTrackingCard(order: o)),
                ],
              ),
            ),
    );
  }
}

class _AdminCourierMap extends ConsumerWidget {
  const _AdminCourierMap({required this.orders});

  final List<Order> orders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);

    return branchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const SizedBox.shrink(),
      data: (branches) {
        final branchById = {
          for (final branch in branches)
            branch.id: LatLng(branch.latitude, branch.longitude),
        };

        return OsmActiveDeliveriesMapView(
          orders: orders,
          branchById: branchById,
          height: 320,
        );
      },
    );
  }
}

class _DeliveryTrackingCard extends StatelessWidget {
  const _DeliveryTrackingCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final duration = order.deliveryDurationMinutes;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ListTile(
        title: Text(
          LocaleKeys.orderNumber.tr(
            namedArgs: {'number': '${order.orderNumber}'},
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(OrderStatusUtils.label(order.status)),
            if (order.courierName != null)
              Text(
                LocaleKeys.orderTrackingCourierName.tr(
                  namedArgs: {'name': order.courierName!},
                ),
              ),
            if (duration != null)
              Text(
                LocaleKeys.deliveryDurationMinutes.tr(
                  namedArgs: {'minutes': '$duration'},
                ),
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        trailing: Icon(
          switch (order.status) {
            OrderStatus.onTheWay => Icons.two_wheeler,
            OrderStatus.waitingCourier => Icons.delivery_dining,
            OrderStatus.delivered => Icons.check_circle,
            _ => Icons.local_shipping_outlined,
          },
          color: switch (order.status) {
            OrderStatus.onTheWay => AppColors.primary,
            OrderStatus.waitingCourier => AppColors.warning,
            OrderStatus.delivered => AppColors.success,
            _ => AppColors.textSecondary,
          },
        ),
      ),
    );
  }
}
