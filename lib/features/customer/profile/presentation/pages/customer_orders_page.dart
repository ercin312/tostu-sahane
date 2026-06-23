import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/cart_item_display_utils.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../core/utils/order_status_utils.dart';
import '../../../../../core/utils/payment_method_utils.dart';
import '../../../../../shared/data/mock/mock_data.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../home/presentation/providers/branch_provider.dart';
import '../../../product_detail/presentation/providers/product_reviews_provider.dart';
import '../../../orders/presentation/utils/customer_reorder_utils.dart';
import '../../../order_tracking/presentation/widgets/order_rating_sheet.dart';
import '../../../orders/presentation/widgets/recommended_products_section.dart';

class CustomerOrdersPage extends ConsumerWidget {
  const CustomerOrdersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersProvider);
    final activeCount = ref.watch(customerActiveOrdersProvider).length;
    final historyCount = ref.watch(customerHistoryOrdersProvider).length;
    final initialTab = activeCount == 0 && historyCount > 0 ? 1 : 0;

    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(LocaleKeys.customerOrdersTitle.tr()),
          backgroundColor: AppColors.white,
          elevation: 0,
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(LocaleKeys.orderActive.tr()),
                    if (ordersAsync.valueOrNull != null) ...[
                      Builder(
                        builder: (context) {
                          final count =
                              ref.watch(customerActiveOrdersProvider).length;
                          if (count == 0) return const SizedBox.shrink();
                          return Row(
                            children: [
                              const SizedBox(width: 6),
                              _CountBadge(count: count),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(LocaleKeys.orderPast.tr()),
                    if (ordersAsync.valueOrNull != null) ...[
                      Builder(
                        builder: (context) {
                          final count =
                              ref.watch(customerHistoryOrdersProvider).length;
                          if (count == 0) return const SizedBox.shrink();
                          return Row(
                            children: [
                              const SizedBox(width: 6),
                              _CountBadge(count: count),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        body: ordersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(LocaleKeys.commonError.tr()),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () =>
                      ref.read(ordersProvider.notifier).refresh(),
                  child: Text(LocaleKeys.commonRetry.tr()),
                ),
              ],
            ),
          ),
          data: (_) {
            final activeOrders = ref.watch(customerActiveOrdersProvider);
            final historyOrders = ref.watch(customerHistoryOrdersProvider);

            return TabBarView(
              children: [
                _OrdersList(
                  orders: activeOrders,
                  emptyMessage: LocaleKeys.orderNoActiveOrders.tr(),
                  showReorder: false,
                ),
                _OrdersList(
                  orders: historyOrders,
                  emptyMessage: LocaleKeys.orderNoHistoryOrders.tr(),
                  showReorder: true,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _OrdersList extends ConsumerWidget {
  const _OrdersList({
    required this.orders,
    required this.emptyMessage,
    required this.showReorder,
  });

  final List<Order> orders;
  final String emptyMessage;
  final bool showReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    emptyMessage,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: RecommendedProductsSection()),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) => _CustomerOrderCard(
          order: orders[index],
          showReorder: showReorder && customerCanReorder(orders[index]),
          onTrack: () => context.push(
            RoutePaths.customerOrderTrack(orders[index].id),
          ),
          onReorder: () => reorderCustomerOrder(context, ref, orders[index]),
        ),
      ),
    );
  }
}

class _CustomerOrderCard extends ConsumerWidget {
  const _CustomerOrderCard({
    required this.order,
    required this.showReorder,
    required this.onTrack,
    required this.onReorder,
  });

  final Order order;
  final bool showReorder;
  final VoidCallback onTrack;
  final VoidCallback onReorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider).value ?? [];
    final pendingReviewOrderIds = ref.watch(orderIdsWithPendingReviewProvider);
    final branchName = branches
        .where((b) => b.id == order.branchId)
        .map((b) => b.name)
        .firstOrNull;
    final catalog =
        ref.watch(catalogExtrasProvider).value ?? MockData.catalogExtras;

    final statusColor = switch (order.status) {
      OrderStatus.cancelled => AppColors.error,
      OrderStatus.delivered => AppColors.success,
      _ => AppColors.primary,
    };

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTrack,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
          ),
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      OrderStatusUtils.label(order.status),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd.MM.yyyy HH:mm').format(order.createdAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              if (branchName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.storefront_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        branchName,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              ...order.items.take(3).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        CartItemDisplayUtils.quantityLine(item, catalog),
                        style: Theme.of(context).textTheme.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              if (order.items.length > 3)
                Text(
                  LocaleKeys.orderMoreItems.tr(
                    namedArgs: {'count': '${order.items.length - 3}'},
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    FormatUtils.currency(order.totalAmount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '· ${PaymentMethodUtils.label(order.paymentMethod)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (order.rating != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: List.generate(
                    order.rating!,
                    (_) => const Icon(Icons.star, color: Colors.amber, size: 16),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  TextButton.icon(
                    onPressed: onTrack,
                    style: TextButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: Text(LocaleKeys.orderTrack.tr()),
                  ),
                  if (showReorder && customerCanReorder(order))
                    TextButton.icon(
                      onPressed: onReorder,
                      style: TextButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: Text(LocaleKeys.orderReorder.tr()),
                    ),
                  if (showReorder &&
                      order.status == OrderStatus.delivered &&
                      order.rating == null &&
                      !pendingReviewOrderIds.contains(order.id))
                    TextButton.icon(
                      onPressed: () => OrderRatingSheet.show(context, order),
                      style: TextButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.star_outline, size: 18),
                      label: Text(LocaleKeys.orderRateAction.tr()),
                    ),
                  if (showReorder &&
                      order.status == OrderStatus.delivered &&
                      order.rating == null &&
                      pendingReviewOrderIds.contains(order.id))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Chip(
                        label: Text(
                          LocaleKeys.orderRatingPendingApproval.tr(),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        backgroundColor:
                            AppColors.warning.withValues(alpha: 0.12),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
