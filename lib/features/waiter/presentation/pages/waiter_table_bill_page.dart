import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/pos/pos_terminal_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/cart_item_display_utils.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/utils/order_modifiers_utils.dart';
import '../../../../core/widgets/order_cart_item_rows.dart';
import '../../../customer/home/presentation/providers/branch_provider.dart';
import '../../../../shared/data/mock/mock_data.dart';
import '../../../../shared/domain/entities/order.dart';
import '../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../providers/table_sessions_provider.dart';
import '../../../../core/widgets/order_modifiers_panel.dart';
import '../../../../core/widgets/order_preparation_preferences_panel.dart';
import '../../../../core/utils/waiter_order_notes.dart';

class WaiterTableBillPage extends ConsumerStatefulWidget {
  const WaiterTableBillPage({
    super.key,
    required this.tableNumber,
    this.cashierMode = false,
    this.returnPath,
  });

  final int tableNumber;
  final bool cashierMode;
  final String? returnPath;

  @override
  ConsumerState<WaiterTableBillPage> createState() =>
      _WaiterTableBillPageState();
}

class _WaiterTableBillPageState extends ConsumerState<WaiterTableBillPage> {
  var _closing = false;
  var _voiding = false;
  var _cancellingItem = false;

  String get _homePath =>
      widget.returnPath ??
      (widget.cashierMode
          ? RoutePaths.branchCashier
          : RoutePaths.branchWaiter);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
    });
  }

  Future<void> _closeWithPayment(PaymentMethod method) async {
    final session = ref.read(tableSessionProvider(widget.tableNumber));
    if (session == null || !session.isOpen) return;

    if (method == PaymentMethod.cardOnDelivery) {
      final settings = ref.read(waiterModeSettingsProvider).valueOrNull;
      if (settings == null || !settings.posEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.waiterPosNotConfigured.tr())),
        );
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.waiterCloseBillConfirmTitle.tr()),
        content: Text(
          LocaleKeys.waiterCloseBillConfirmBody.tr(
            namedArgs: {
              'table': '${widget.tableNumber}',
              'amount': FormatUtils.currency(session.totalAmount),
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(LocaleKeys.waiterCloseBillConfirmAction.tr()),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _closing = true);
    try {
      String? txnId;
      if (method == PaymentMethod.cardOnDelivery) {
        final settings = ref.read(waiterModeSettingsProvider).value!;
        final reference =
            'MASA-${widget.tableNumber}-${DateTime.now().millisecondsSinceEpoch}';
        final result = await PosTerminalService.chargeCard(
          amount: session.totalAmount,
          reference: reference,
          settings: settings,
        );
        if (!result.success) {
          throw const PosTerminalException('waiter_pos_failed');
        }
        txnId = result.transactionId;
      }

      await ref.read(ordersProvider.notifier).closeDineInTableBill(
            tableNumber: widget.tableNumber,
            paymentMethod: method,
            paymentTransactionId: txnId,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      context.go(_homePath);
    } on PosTerminalException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(e.messageKey.tr()),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _voidBill() async {
    final session = ref.read(tableSessionProvider(widget.tableNumber));
    if (session == null || !session.isOpen) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.waiterVoidBillConfirmTitle.tr()),
        content: Text(
          LocaleKeys.waiterVoidBillConfirmBody.tr(
            namedArgs: {'table': '${widget.tableNumber}'},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(LocaleKeys.waiterVoidBillConfirmAction.tr()),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _voiding = true);
    try {
      await ref.read(ordersProvider.notifier).voidDineInTableBill(
            tableNumber: widget.tableNumber,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocaleKeys.waiterVoidBillDone.tr(
              namedArgs: {'table': '${widget.tableNumber}'},
            ),
          ),
        ),
      );
      context.go(_homePath);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    } finally {
      if (mounted) setState(() => _voiding = false);
    }
  }

  Future<void> _cancelItem(Order order, CartItem item) async {
    if (_closing || _voiding || _cancellingItem) return;

    final productName = CartItemDisplayUtils.productTitle(item);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.waiterCancelItemConfirmTitle.tr()),
        content: Text(
          LocaleKeys.waiterCancelItemConfirmBody.tr(
            namedArgs: {'item': productName},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(LocaleKeys.waiterCancelItemConfirmAction.tr()),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _cancellingItem = true);
    try {
      await ref.read(ordersProvider.notifier).removeDineInOrderItem(
            order.id,
            item.id,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.waiterItemCancelled.tr())),
      );

      final session = ref.read(tableSessionProvider(widget.tableNumber));
      if (session == null || !session.isOpen) {
        context.go(_homePath);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    } finally {
      if (mounted) setState(() => _cancellingItem = false);
    }
  }

  bool get _busy => _closing || _voiding || _cancellingItem;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(tableSessionProvider(widget.tableNumber));
    final catalog =
        ref.watch(catalogExtrasProvider).value ?? MockData.catalogExtras;

    if (session == null || !session.isOpen) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            LocaleKeys.waiterTableBillTitle.tr(
              namedArgs: {'table': '${widget.tableNumber}'},
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  LocaleKeys.waiterTableEmptyBill.tr(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!widget.cashierMode)
                  ElevatedButton(
                    onPressed: () => context.go(
                      RoutePaths.branchWaiterOrder(widget.tableNumber),
                    ),
                    child: Text(LocaleKeys.waiterAddOrder.tr()),
                  )
                else
                  OutlinedButton(
                    onPressed: () => context.go(_homePath),
                    child: Text(LocaleKeys.cashierBackToTables.tr()),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.waiterTableBillTitle.tr(
            namedArgs: {'table': '${widget.tableNumber}'},
          ),
          style: const TextStyle(fontSize: 17),
        ),
        toolbarHeight: 48,
        actions: [
          if (!widget.cashierMode)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => context.push(
                        RoutePaths.branchWaiterOrder(widget.tableNumber),
                      ),
              child: Text(LocaleKeys.waiterAddOrder.tr()),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              children: [
                Row(
                  children: [
                    Text(
                      LocaleKeys.dineInTableLabel.tr(
                        namedArgs: {'table': '${widget.tableNumber}'},
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      LocaleKeys.waiterOpenOrdersCount.tr(
                        namedArgs: {'count': '${session.orderCount}'},
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                ...session.openOrders.expand((order) {
                  return [
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpacing.sm,
                        bottom: 4,
                      ),
                      child: Text(
                        '#${order.orderNumber} · ${DateFormat.Hm().format(order.createdAt)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    ...order.items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: OrderCartItemRow(
                          item: item,
                          catalog: catalog,
                          onRemove: _busy
                              ? null
                              : () => _cancelItem(order, item),
                        ),
                      ),
                    ),
                    if (OrderModifiersUtils.hasModifiers(order))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OrderModifiersPanel(order: order, compact: true),
                      ),
                    if (WaiterOrderNotes.hasNote(order))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OrderPreparationPreferencesPanel(
                          order: order,
                          compact: true,
                        ),
                      ),
                  ];
                }),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        LocaleKeys.waiterBillTotal.tr(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        FormatUtils.currency(session.totalAmount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton(
                            onPressed: _busy
                                ? null
                                : () => _closeWithPayment(
                                      PaymentMethod.cashOnDelivery,
                                    ),
                            style: OutlinedButton.styleFrom(
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                            child: Text(LocaleKeys.waiterPayCash.tr()),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: _busy
                                ? null
                                : () => _closeWithPayment(
                                      PaymentMethod.cardOnDelivery,
                                    ),
                            style: ElevatedButton.styleFrom(
                              textStyle: const TextStyle(fontSize: 13),
                            ),
                            child: _closing
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(LocaleKeys.waiterPayCard.tr()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 42,
                    child: OutlinedButton(
                      onPressed: _busy ? null : _voidBill,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                      child: _voiding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.error,
                              ),
                            )
                          : Text(LocaleKeys.waiterVoidBill.tr()),
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
