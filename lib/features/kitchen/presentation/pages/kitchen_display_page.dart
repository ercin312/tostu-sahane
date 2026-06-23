import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/orders/order_workflow.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/cart_item_display_utils.dart';
import '../../../../core/utils/localized_text.dart';
import '../../../../core/utils/waiter_preparation_tags.dart';
import '../../../../core/widgets/role_logout_action.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/customer/home/presentation/providers/branch_provider.dart';
import '../../../../shared/data/mock/mock_data.dart';
import '../../../../shared/domain/entities/order.dart';
import '../../../../shared/domain/entities/product_extra.dart';
import '../../../../shared/presentation/providers/orders_provider.dart';
import '../utils/kitchen_timeline_layout.dart';

/// Uzaktan okuma için mutfak ekranı tipografi ölçekleri.
abstract final class _KitchenType {
  static const tableNumber = 34.0;
  static const orderNumber = 20.0;
  static const meta = 16.0;
  static const prepTag = 20.0;
  static const orderNote = 18.0;
  static const itemQty = 24.0;
  static const itemTitle = 26.0;
  static const itemDetail = 18.0;
  static const itemNote = 18.0;
}

enum _KitchenAgeTone { fresh, warming, settled }

_KitchenAgeTone _ageToneFor(Order order, DateTime now) {
  final minutes = now.difference(order.createdAt).inMinutes;
  if (minutes < 5) return _KitchenAgeTone.fresh;
  if (minutes < 15) return _KitchenAgeTone.warming;
  return _KitchenAgeTone.settled;
}

Color _toneAccent(_KitchenAgeTone tone) {
  return switch (tone) {
    _KitchenAgeTone.fresh => const Color(0xFF4CAF50),
    _KitchenAgeTone.warming => const Color(0xFFFF9800),
    _KitchenAgeTone.settled => const Color(0xFF5C5C5C),
  };
}

Color _toneSurface(_KitchenAgeTone tone) {
  return switch (tone) {
    _KitchenAgeTone.fresh => const Color(0xFF1A2E1C),
    _KitchenAgeTone.warming => const Color(0xFF2A2218),
    _KitchenAgeTone.settled => const Color(0xFF1A1A1A),
  };
}

int _columnCountForWidth(double width) =>
    KitchenTimelineLayout.columnCountForWidth(width);

class KitchenDisplayPage extends ConsumerWidget {
  const KitchenDisplayPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branch = ref.watch(managedBranchProvider).value;
    final queue = ref.watch(kitchenQueueOrdersProvider);
    final now = DateTime.now();
    final sorted = List<Order>.of(queue)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleKeys.kitchenDisplayTitle.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (branch != null)
                  Text(
                    branch.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                        ),
                  ),
              ],
            ),
            if (sorted.isNotEmpty) ...[
              const SizedBox(width: AppSpacing.md),
              _QueueBadge(count: sorted.length),
            ],
          ],
        ),
        actions: [
          _LegendChip(
            color: _toneAccent(_KitchenAgeTone.fresh),
            label: LocaleKeys.kitchenLegendFresh.tr(),
          ),
          const SizedBox(width: 6),
          _LegendChip(
            color: _toneAccent(_KitchenAgeTone.warming),
            label: LocaleKeys.kitchenLegendWarming.tr(),
          ),
          const SizedBox(width: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Center(
              child: Text(
                DateFormat('HH:mm').format(now),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          const RoleLogoutAction(),
        ],
      ),
      body: sorted.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    LocaleKeys.kitchenDisplayEmpty.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white38,
                        ),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final columnCount = _columnCountForWidth(constraints.maxWidth);
                final lanes = KitchenTimelineLayout.distributeLanes(
                  sorted,
                  maxColumns: columnCount,
                );

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < lanes.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 1,
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      Expanded(
                        child: _KitchenTimelineColumn(
                          orders: lanes[i],
                          now: now,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _QueueBadge extends StatelessWidget {
  const _QueueBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _KitchenTimelineColumn extends StatelessWidget {
  const _KitchenTimelineColumn({
    required this.orders,
    required this.now,
  });

  final List<Order> orders;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final isLast = index == orders.length - 1;
        return _KitchenTimelineTicket(
          order: order,
          now: now,
          showConnector: !isLast,
        );
      },
    );
  }
}

class _KitchenTimelineTicket extends ConsumerStatefulWidget {
  const _KitchenTimelineTicket({
    required this.order,
    required this.now,
    required this.showConnector,
  });

  final Order order;
  final DateTime now;
  final bool showConnector;

  @override
  ConsumerState<_KitchenTimelineTicket> createState() =>
      _KitchenTimelineTicketState();
}

class _KitchenTimelineTicketState extends ConsumerState<_KitchenTimelineTicket> {
  var _busy = false;

  Order get order => widget.order;

  Future<void> _runAction(OrderWorkflowAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(ordersProvider.notifier)
          .performWorkflowAction(order.id, action);
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
    final tone = _ageToneFor(order, widget.now);
    final accent = _toneAccent(tone);
    final elapsed = widget.now.difference(order.createdAt).inMinutes;
    final canAccept = auth != null &&
        OrderWorkflow.canPerform(auth.user, order, OrderWorkflowAction.accept);
    final canReady = auth != null &&
        OrderWorkflow.canPerform(auth.user, order, OrderWorkflowAction.markReady);
    final catalog =
        ref.watch(catalogExtrasProvider).value ?? MockData.catalogExtras;
    final isPreparing = order.status == OrderStatus.preparing;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 14),
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    boxShadow: tone == _KitchenAgeTone.fresh
                        ? [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.55),
                              blurRadius: 6,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (widget.showConnector)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 2),
              child: Material(
                color: _toneSurface(tone),
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: accent.withValues(
                        alpha: tone == _KitchenAgeTone.settled ? 0.15 : 0.45,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _TableHero(tableNumber: order.tableNumber),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        '#${order.orderNumber}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: _KitchenType.orderNumber,
                                          height: 1.1,
                                        ),
                                      ),
                                      if (isPreparing) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.soup_kitchen_outlined,
                                          size: 22,
                                          color: accent.withValues(alpha: 0.9),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _metaLine(order, elapsed),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: _KitchenType.meta,
                                      height: 1.25,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_busy)
                              const Padding(
                                padding: EdgeInsets.all(6),
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white54,
                                  ),
                                ),
                              )
                            else ...[
                              if (canAccept)
                                _KitchenIconAction(
                                  icon: Icons.play_arrow_rounded,
                                  color: AppColors.primary,
                                  tooltip:
                                      LocaleKeys.kitchenStartPreparing.tr(),
                                  onPressed: () => _runAction(
                                    OrderWorkflowAction.accept,
                                  ),
                                ),
                              if (canReady)
                                _KitchenIconAction(
                                  icon: Icons.check_rounded,
                                  color: AppColors.success,
                                  tooltip: LocaleKeys.kitchenMarkReady.tr(),
                                  onPressed: () => _runAction(
                                    OrderWorkflowAction.markReady,
                                  ),
                                ),
                            ],
                          ],
                        ),
                        if (order.preparationTags.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final tag in order.preparationTags)
                                _TagPill(
                                  label: WaiterPreparationTags.label(tag),
                                  highlight: true,
                                ),
                            ],
                          ),
                        ],
                        if (order.orderNote != null &&
                            order.orderNote!.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            order.orderNote!.trim(),
                            style: TextStyle(
                              color: AppColors.warning.withValues(alpha: 0.95),
                              fontSize: _KitchenType.orderNote,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        const Divider(height: 1, color: Color(0x22FFFFFF)),
                        const SizedBox(height: 10),
                        _KitchenItemLines(
                          items: order.items,
                          catalog: catalog,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _metaLine(Order order, int elapsed) {
    final parts = <String>[
      LocaleKeys.kitchenElapsedMinutes.tr(
        namedArgs: {'minutes': '$elapsed'},
      ),
    ];
    final waiter = order.waiterCode ?? order.waiterName;
    if (waiter != null && waiter.isNotEmpty) {
      parts.add(
        LocaleKeys.dineInWaiterLabel.tr(namedArgs: {'name': waiter}),
      );
    }
    if (order.status == OrderStatus.received) {
      parts.add(LocaleKeys.kitchenColumnNew.tr());
    } else {
      parts.add(LocaleKeys.kitchenColumnPreparing.tr());
    }
    return parts.join(' · ');
  }
}

class _TableHero extends StatelessWidget {
  const _TableHero({required this.tableNumber});

  final int? tableNumber;

  @override
  Widget build(BuildContext context) {
    final number = tableNumber ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            LocaleKeys.dineInTableField.tr(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$number',
            style: const TextStyle(
              color: Colors.white,
              fontSize: _KitchenType.tableNumber,
              fontWeight: FontWeight.w900,
              height: 1,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, this.highlight = false});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.warning.withValues(alpha: 0.22)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: highlight
            ? Border.all(color: AppColors.warning.withValues(alpha: 0.45))
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlight ? AppColors.warning : Colors.white70,
          fontSize: _KitchenType.prepTag,
          fontWeight: FontWeight.w800,
          height: 1.15,
        ),
      ),
    );
  }
}

class _KitchenIconAction extends StatelessWidget {
  const _KitchenIconAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: Icon(icon, size: 26, color: color),
      style: IconButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _KitchenItemLines extends StatelessWidget {
  const _KitchenItemLines({
    required this.items,
    required this.catalog,
  });

  final List<CartItem> items;
  final List<ProductExtra> catalog;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _KitchenItemLine(item: items[i], catalog: catalog),
        ],
      ],
    );
  }
}

class _KitchenItemLine extends StatelessWidget {
  const _KitchenItemLine({
    required this.item,
    required this.catalog,
  });

  final CartItem item;
  final List<ProductExtra> catalog;

  @override
  Widget build(BuildContext context) {
    final extras = CartItemDisplayUtils.extraLabels(item, catalog);
    final title = CartItemDisplayUtils.productTitle(item);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          child: Text(
            '${item.quantity}×',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: _KitchenType.itemQty,
              height: 1.2,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: _KitchenType.itemTitle,
                  height: 1.2,
                ),
              ),
              if (item.portionKey != null)
                Text(
                  localizedOrRaw(item.portionKey!),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: _KitchenType.itemDetail,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (extras.isNotEmpty)
                Text(
                  '+ ${extras.join(' · ')}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: _KitchenType.itemDetail,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (item.note != null && item.note!.trim().isNotEmpty)
                Text(
                  '“${item.note!.trim()}”',
                  style: TextStyle(
                    color: AppColors.warning.withValues(alpha: 0.9),
                    fontSize: _KitchenType.itemNote,
                    fontStyle: FontStyle.italic,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
