import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/order_status_utils.dart';
import '../../../../../core/utils/platform_layout_utils.dart';
import '../../../../../core/widgets/osm_tile_map_view.dart';
import '../../../../../features/customer/home/presentation/providers/branch_provider.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';

/// Şube Windows/mobil: aktif teslimatlar haritası (yalnız kendi şubesi).
class BranchCourierTrackingPage extends ConsumerStatefulWidget {
  const BranchCourierTrackingPage({super.key});

  @override
  ConsumerState<BranchCourierTrackingPage> createState() =>
      _BranchCourierTrackingPageState();
}

class _BranchCourierTrackingPageState
    extends ConsumerState<BranchCourierTrackingPage> {
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
    final branch = ref.watch(managedBranchProvider).value;
    final all = ref.watch(activeDeliveryOrdersProvider);
    final deliveries = branch == null
        ? const <Order>[]
        : all.where((o) => o.branchId == branch.id).toList();
    final mapHeight = PlatformLayout.useDesktopLayout(context) ? 420.0 : 320.0;

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
                    height: mapHeight,
                    child: _BranchCourierMap(
                      orders: deliveries,
                      mapHeight: mapHeight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    LocaleKeys.adminCourierTrackingList.tr(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...deliveries.map((o) => _BranchDeliveryCard(order: o)),
                ],
              ),
            ),
    );
  }
}

class _BranchCourierMap extends ConsumerWidget {
  const _BranchCourierMap({
    required this.orders,
    required this.mapHeight,
  });

  final List<Order> orders;
  final double mapHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);

    return branchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
      data: (branches) {
        final branchById = {
          for (final branch in branches)
            branch.id: LatLng(branch.latitude, branch.longitude),
        };

        return OsmActiveDeliveriesMapView(
          orders: orders,
          branchById: branchById,
          height: mapHeight,
        );
      },
    );
  }
}

class _BranchDeliveryCard extends StatelessWidget {
  const _BranchDeliveryCard({required this.order});

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
