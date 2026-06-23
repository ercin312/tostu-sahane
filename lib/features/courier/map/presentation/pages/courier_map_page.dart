import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/maps_navigation_utils.dart';
import '../../../../../core/utils/order_status_utils.dart';
import '../../../../../core/widgets/delivery_map_view.dart';
import '../../../../../core/widgets/live_delivery_map_view.dart';
import '../../../../../features/customer/home/presentation/providers/branch_provider.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';

class CourierMapPage extends ConsumerWidget {
  const CourierMapPage({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderByIdProvider(orderId));
    final branchesAsync = ref.watch(branchesProvider);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(LocaleKeys.commonError.tr())),
      );
    }

    return branchesAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(LocaleKeys.courierMapTitle.tr())),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: AppBar(title: Text(LocaleKeys.courierMapTitle.tr())),
        body: Center(child: Text(LocaleKeys.commonError.tr())),
      ),
      data: (branches) {
        if (branches.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(LocaleKeys.courierMapTitle.tr())),
            body: Center(child: Text(LocaleKeys.commonError.tr())),
          );
        }

        final branch = branches.firstWhere(
          (b) => b.id == order.branchId,
          orElse: () => branches.first,
        );
        final deliveryLat = order.deliveryLatitude ?? branch.latitude + 0.012;
        final deliveryLng = order.deliveryLongitude ?? branch.longitude + 0.008;
        final distanceKm = estimateRouteKm(
          branch.latitude,
          branch.longitude,
          deliveryLat,
          deliveryLng,
        );

        return Scaffold(
          appBar: AppBar(title: Text(LocaleKeys.courierMapTitle.tr())),
          body: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                LocaleKeys.orderNumber.tr(
                  namedArgs: {'number': '${order.orderNumber}'},
                ),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(OrderStatusUtils.label(order.status)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                LocaleKeys.mapUsingOsm.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              LiveDeliveryMapView(
                branchLat: branch.latitude,
                branchLng: branch.longitude,
                deliveryLat: deliveryLat,
                deliveryLng: deliveryLng,
                courierLat: order.courierLatitude,
                courierLng: order.courierLongitude,
                height: 360,
                animateCourier: order.status == OrderStatus.onTheWay,
              ),
              const SizedBox(height: AppSpacing.md),
              _InfoTile(
                icon: Icons.store,
                title: branch.name,
                subtitle: branch.address,
              ),
              _InfoTile(
                icon: Icons.location_on,
                title: LocaleKeys.courierMapDestination.tr(),
                subtitle: order.address,
              ),
              _InfoTile(
                icon: Icons.route,
                title: LocaleKeys.courierMapDistance.tr(),
                subtitle: LocaleKeys.courierMapDistanceValue.tr(
                  namedArgs: {'km': distanceKm.toStringAsFixed(1)},
                ),
              ),
              _InfoTile(
                icon: Icons.payments_outlined,
                title: LocaleKeys.customerTotal.tr(),
                subtitle: FormatUtils.currency(order.totalAmount),
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => MapsNavigationUtils.openNavigation(
                  address: order.address,
                  latitude: order.deliveryLatitude,
                  longitude: order.deliveryLongitude,
                ),
                icon: const Icon(Icons.navigation),
                label: Text(LocaleKeys.courierNavigate.tr()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      subtitle: Text(subtitle),
    );
  }
}
