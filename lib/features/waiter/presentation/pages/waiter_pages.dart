import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/media/media_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/utils/localized_text.dart';
import '../../../../core/utils/waiter_utils.dart';
import '../../../../core/utils/waiter_preparation_tags.dart';
import '../../../../core/widgets/role_logout_action.dart';
import '../../../customer/home/presentation/providers/branch_provider.dart';
import '../../../../shared/domain/entities/order.dart';
import '../providers/waiter_cart_provider.dart';
import '../providers/waiter_products_provider.dart';
import '../../../../core/widgets/preparation_tags_chips.dart';
import '../widgets/waiter_preparation_tags_sheet.dart';
import '../widgets/waiter_pos_menu_panel.dart';
import '../../domain/waiter_pos_catalog.dart';
import '../providers/table_sessions_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../shared/domain/entities/waiter_mode_settings.dart';
import '../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../domain/table_session.dart';
import '../widgets/waiter_table_chip.dart';
import '../widgets/waiter_table_picker_dialog.dart';

class WaiterTablePage extends ConsumerStatefulWidget {
  const WaiterTablePage({super.key});

  @override
  ConsumerState<WaiterTablePage> createState() => _WaiterTablePageState();
}

class _WaiterTablePageState extends ConsumerState<WaiterTablePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
    });
  }

  void _openPickup() {
    ref.read(waiterCartProvider.notifier).clear();
    context.push(RoutePaths.branchWaiterPickup);
  }

  void _openTable(int tableNumber) {
    final session = ref.read(tableSessionProvider(tableNumber));
    if (session != null && session.isOpen) {
      context.push(RoutePaths.branchWaiterBill(tableNumber));
      return;
    }
    ref.read(waiterCartProvider.notifier).clear();
    context.push(RoutePaths.branchWaiterOrder(tableNumber));
  }

  void _onTableLongPress(int tableNumber) {
    final session = ref.read(tableSessionProvider(tableNumber));
    if (session == null || !session.isOpen) return;
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: Text(LocaleKeys.waiterViewBill.tr()),
              subtitle: Text(FormatUtils.currency(session.totalAmount)),
              onTap: () {
                Navigator.pop(context);
                context.push(RoutePaths.branchWaiterBill(tableNumber));
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: Text(LocaleKeys.waiterAddOrder.tr()),
              onTap: () {
                Navigator.pop(context);
                ref.read(waiterCartProvider.notifier).clear();
                context.push(RoutePaths.branchWaiterOrder(tableNumber));
              },
            ),
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text(LocaleKeys.waiterChangeTable.tr()),
              onTap: () {
                Navigator.pop(context);
                _changeTableNumber(tableNumber);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeTableNumber(int fromTable) async {
    final toTable = await showWaiterTablePicker(
      context,
      title: LocaleKeys.waiterChangeTableTitle.tr(),
      subtitle: LocaleKeys.waiterChangeTableHint.tr(),
      excludeTable: fromTable,
      highlightTable: fromTable,
    );
    if (toTable == null || !mounted) return;
    if (toTable == fromTable) return;

    final target = ref.read(tableSessionProvider(toTable));
    if (target != null && target.isOpen) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(LocaleKeys.waiterChangeTable.tr()),
          content: Text(LocaleKeys.waiterChangeTableOccupied.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(LocaleKeys.commonCancel.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(LocaleKeys.commonOk.tr()),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }

    try {
      await ref.read(ordersProvider.notifier).moveDineInTable(
            fromTableNumber: fromTable,
            toTableNumber: toTable,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocaleKeys.waiterChangeTableSuccess.tr(
              namedArgs: {
                'from': '$fromTable',
                'to': '$toTable',
              },
            ),
          ),
        ),
      );
      context.go(RoutePaths.branchWaiterBill(toTable));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final branch = ref.watch(managedBranchProvider).value;
    final tableCount = ref.watch(waiterModeSettingsProvider).valueOrNull?.tableCount ??
        WaiterModeSettings.defaults.tableCount;
    final sessions = ref.watch(branchTableSessionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          LocaleKeys.waiterModeTitle.tr(),
          style: const TextStyle(fontSize: 18),
        ),
        toolbarHeight: 48,
        actions: const [RoleLogoutAction()],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const hPad = AppSpacing.sm;
          const gridSpacing = 6.0;
          final width = constraints.maxWidth - hPad * 2;
          final crossAxisCount = width >= 720
              ? 8
              : width >= 540
                  ? 6
                  : width >= 400
                      ? 5
                      : 4;
          // Mobil/Windows aynı: ekrana sığdır (Windows masa haritası mantığı).
          final rowCount = (tableCount + crossAxisCount - 1) ~/ crossAxisCount;
          final headerBlock = branch != null ? 52.0 : 36.0;
          final pickupBlock = 44.0 + AppSpacing.xs;
          final aspectRatio = () {
            final gridHeight = (constraints.maxHeight -
                    headerBlock -
                    pickupBlock -
                    AppSpacing.xs * 3 -
                    gridSpacing * (rowCount - 1))
                .clamp(80.0, double.infinity);
            final cellWidth =
                (width - gridSpacing * (crossAxisCount - 1)) / crossAxisCount;
            final cellHeight = gridHeight / rowCount;
            return (cellWidth / cellHeight).clamp(0.65, 1.35);
          }();

          return Padding(
            padding: const EdgeInsets.fromLTRB(hPad, AppSpacing.xs, hPad, hPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (branch != null)
                  Text(
                    LocaleKeys.branchAssignedLabel.tr(
                      namedArgs: {'name': branch.name},
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                Text(
                  LocaleKeys.waiterSelectTable.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: _openPickup,
                    icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                    label: Text(
                      LocaleKeys.waiterPickup.tr(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Expanded(
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: gridSpacing,
                      crossAxisSpacing: gridSpacing,
                      childAspectRatio: aspectRatio,
                    ),
                    itemCount: tableCount,
                    itemBuilder: (context, index) {
                      final tableNumber = index + 1;
                      final session = index < sessions.length
                          ? sessions[index]
                          : TableSession(
                              tableNumber: tableNumber,
                              openOrders: const [],
                            );
                      return WaiterTableChip(
                        label: '$tableNumber',
                        compact: true,
                        isOpen: session.isOpen,
                        totalAmount:
                            session.isOpen ? session.totalAmount : null,
                        onTap: () => _openTable(tableNumber),
                        onLongPress: () => _onTableLongPress(tableNumber),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class WaiterOrderPage extends ConsumerStatefulWidget {
  const WaiterOrderPage({
    super.key,
    this.tableNumber,
    this.isPickup = false,
  });

  final int? tableNumber;
  final bool isPickup;

  @override
  ConsumerState<WaiterOrderPage> createState() => _WaiterOrderPageState();
}

class _WaiterOrderPageState extends ConsumerState<WaiterOrderPage> {
  final _noteController = TextEditingController();
  var _submitting = false;
  var _preparationTags = <String>{};
  WaiterPosSection _section = WaiterPosSection.tostlar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      _prefetchMenuImages();
    });
  }

  void _prefetchMenuImages() {
    final products = ref.read(waiterBranchProductsProvider);
    for (final product in products) {
      final url = product.imageUrl?.trim();
      if (url == null || url.isEmpty) continue;
      if (!MediaStorageService.isNetworkSource(url)) continue;
      precacheImage(NetworkImage(url), context);
    }
  }

  Future<PaymentMethod?> _pickPaymentMethod() async {
    return showDialog<PaymentMethod>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.waiterPickupPaymentTitle.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: Text(LocaleKeys.waiterPickupPaymentCash.tr()),
              onTap: () =>
                  Navigator.pop(ctx, PaymentMethod.cashOnDelivery),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: Text(LocaleKeys.waiterPickupPaymentCard.tr()),
              onTap: () =>
                  Navigator.pop(ctx, PaymentMethod.cardOnDelivery),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _openPreparationTags() async {
    final updated = await showWaiterPreparationTagsSheet(
      context,
      selected: _preparationTags,
    );
    if (!mounted) return;
    setState(() => _preparationTags = updated);
  }

  Future<void> _submit() async {
    final auth = ref.read(authProvider);
    final branch = ref.read(managedBranchProvider).value;
    final products = ref.read(waiterBranchProductsProvider);
    final extras = ref.read(waiterCatalogExtrasProvider);
    final cart = ref.read(waiterCartProvider);
    if (auth == null || branch == null) return;
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.waiterCartEmpty.tr())),
      );
      return;
    }

    PaymentMethod paymentMethod = PaymentMethod.cashOnDelivery;
    if (widget.isPickup) {
      final picked = await _pickPaymentMethod();
      if (!mounted) return;
      if (picked == null) return;
      paymentMethod = picked;
    }

    final isTableAddon = !widget.isPickup &&
        widget.tableNumber != null &&
        (ref.read(tableSessionProvider(widget.tableNumber!))?.isOpen ?? false);

    setState(() => _submitting = true);
    try {
      final note = _noteController.text.trim();
      final orderTotal =
          ref.read(waiterCartProvider.notifier).total(products, extras);
      final waiterCode = waiterReceiptCode(
        username: auth.user.username,
        name: auth.user.name,
      );
      final prepOptions = ref
          .read(waiterModeSettingsProvider)
          .valueOrNull
          ?.preparationOptions;
      await ref.read(ordersProvider.notifier).placeDineInOrder(
            items: ref
                .read(waiterCartProvider.notifier)
                .toCartItems(products, extras),
            totalAmount: orderTotal,
            branchId: branch.id,
            tableNumber: widget.isPickup ? null : widget.tableNumber,
            waiterId: auth.user.id,
            waiterName: auth.user.name,
            waiterCode: waiterCode,
            orderNote: note.isEmpty ? null : note,
            // Mutfağa id değil okunabilir etiket gitsin (özel tercihler dahil).
            preparationTags: WaiterPreparationTags.resolveLabels(
              _preparationTags,
              options: prepOptions,
            ),
            paymentMethod: paymentMethod,
            isPickup: widget.isPickup,
            isTableAddon: isTableAddon,
          );
      ref.read(waiterCartProvider.notifier).clear();
      setState(() => _preparationTags = {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      context.go(RoutePaths.branchWaiter);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(waiterCartProvider);
    final products = ref.watch(waiterBranchProductsProvider);
    final extras = ref.watch(waiterCatalogExtrasProvider);
    final total =
        ref.read(waiterCartProvider.notifier).total(products, extras);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          widget.isPickup
              ? LocaleKeys.waiterPickupTitle.tr()
              : LocaleKeys.waiterTableOrderTitle.tr(
                  namedArgs: {'table': '${widget.tableNumber}'},
                ),
          style: const TextStyle(fontSize: 17),
        ),
        toolbarHeight: 48,
        actions: [
          if (!widget.isPickup && widget.tableNumber != null)
            TextButton.icon(
              onPressed: () => context.push(
                RoutePaths.branchWaiterBill(widget.tableNumber!),
              ),
              icon: const Icon(Icons.receipt_long, size: 18),
              label: Text(LocaleKeys.waiterViewBill.tr()),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: WaiterPosMenuPanel(
              section: _section,
              onSectionChanged: (s) => setState(() => _section = s),
            ),
          ),
          _WaiterOrderActionBar(
            cart: cart,
            total: total,
            submitting: _submitting,
            preparationTags: _preparationTags.toList(),
            orderNote: _noteController.text.trim(),
            onEditNote: () => _editOrderNote(context),
            onPreparationTags: _openPreparationTags,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _editOrderNote(BuildContext context) async {
    final note = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: _noteController.text);
        return AlertDialog(
          title: Text(LocaleKeys.waiterOrderNote.tr()),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: LocaleKeys.waiterOrderNoteHint.tr(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LocaleKeys.commonCancel.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(LocaleKeys.commonOk.tr()),
            ),
          ],
        );
      },
    );
    if (note != null) {
      _noteController.text = note;
      setState(() {});
    }
  }
}

class _WaiterOrderActionBar extends StatelessWidget {
  const _WaiterOrderActionBar({
    required this.cart,
    required this.total,
    required this.submitting,
    required this.preparationTags,
    required this.orderNote,
    required this.onEditNote,
    required this.onPreparationTags,
    required this.onSubmit,
  });

  final List<WaiterCartItem> cart;
  final double total;
  final bool submitting;
  final List<String> preparationTags;
  final String orderNote;
  final VoidCallback onEditNote;
  final VoidCallback onPreparationTags;
  final VoidCallback onSubmit;

  bool get hasNote => orderNote.isNotEmpty;
  int get preparationTagCount => preparationTags.length;

  @override
  Widget build(BuildContext context) {
    final itemCount =
        cart.fold<int>(0, (sum, item) => sum + item.quantity);
    final screenH = MediaQuery.sizeOf(context).height;
    // Keep create-order button on-screen even when notes/tags expand.
    final maxExtrasH = (screenH * 0.28).clamp(96.0, 220.0);
    final canSubmit = !submitting && cart.isNotEmpty;

    final extras = <Widget>[
      Row(
        children: [
          _FooterIconButton(
            icon: Icons.sticky_note_2_outlined,
            label: hasNote
                ? LocaleKeys.waiterOrderNote.tr()
                : LocaleKeys.waiterOrderNoteOptional.tr(),
            active: hasNote,
            onTap: onEditNote,
          ),
          const SizedBox(width: 6),
          _FooterIconButton(
            icon: Icons.tune,
            label: LocaleKeys.waiterPrepSheetTitle.tr(),
            active: preparationTagCount > 0,
            badge: preparationTagCount > 0 ? '$preparationTagCount' : null,
            onTap: onPreparationTags,
          ),
        ],
      ),
      if (preparationTags.isNotEmpty || hasNote) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (preparationTags.isNotEmpty)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onPreparationTags,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: PreparationTagsChips(
                        tags: preparationTags,
                        compact: true,
                      ),
                    ),
                  ),
                ),
              if (hasNote) ...[
                if (preparationTags.isNotEmpty) const SizedBox(height: 6),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onEditNote,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.sticky_note_2_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              orderNote,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
      if (cart.isNotEmpty) ...[
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            cart
                .map(
                  (item) =>
                      '${item.quantity}x ${localizedOrRaw(item.displayNameKey)}',
                )
                .join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.25,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    ];

    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.xs,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxExtrasH),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: extras,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: canSubmit ? onSubmit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: canSubmit
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.38),
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.38),
                    foregroundColor: Colors.white,
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.92),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          children: [
                            const Icon(Icons.check_circle_outline, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cart.isEmpty
                                    ? LocaleKeys.waiterCartEmpty.tr()
                                    : LocaleKeys.waiterCreateOrder.tr(),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (itemCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$itemCount',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 8),
                            Text(
                              FormatUtils.currency(total),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterIconButton extends StatelessWidget {
  const _FooterIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: active
            ? AppColors.primary.withValues(alpha: 0.1)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: active ? AppColors.primary : AppColors.textSecondary,
                    ),
                    if (badge != null)
                      Positioned(
                        top: -6,
                        right: -10,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            badge!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color:
                        active ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
