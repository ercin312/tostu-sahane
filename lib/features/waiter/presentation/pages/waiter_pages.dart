import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/utils/localized_text.dart';
import '../../../../core/utils/platform_layout_utils.dart';
import '../../../../core/utils/waiter_utils.dart';
import '../../../../core/widgets/product_thumbnail.dart';
import '../../../../core/widgets/role_logout_action.dart';
import '../../../customer/home/presentation/providers/branch_provider.dart';
import '../../../../shared/domain/entities/product.dart';
import '../providers/waiter_cart_provider.dart';
import '../providers/waiter_products_provider.dart';
import '../widgets/waiter_addons_sheet.dart';
import '../widgets/waiter_preparation_tags_sheet.dart';
import '../providers/table_sessions_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../shared/domain/entities/waiter_mode_settings.dart';
import '../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../domain/table_session.dart';
import '../widgets/waiter_table_chip.dart';

class WaiterTablePage extends ConsumerStatefulWidget {
  const WaiterTablePage({super.key});

  @override
  ConsumerState<WaiterTablePage> createState() => _WaiterTablePageState();
}

class _WaiterTablePageState extends ConsumerState<WaiterTablePage> {
  final _customTableController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
    });
  }

  @override
  void dispose() {
    _customTableController.dispose();
    super.dispose();
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
          ],
        ),
      ),
    );
  }

  void _openCustomTable() {
    final value = int.tryParse(_customTableController.text.trim());
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.waiterInvalidTable.tr())),
      );
      return;
    }
    _openTable(value);
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
          const footerHeight = 44.0;
          final width = constraints.maxWidth - hPad * 2;
          final crossAxisCount = width >= 720
              ? 8
              : width >= 540
                  ? 6
                  : width >= 400
                      ? 5
                      : 4;
          final rowCount = (tableCount + crossAxisCount - 1) ~/ crossAxisCount;
          final headerBlock = branch != null ? 52.0 : 36.0;
          final gridHeight = (constraints.maxHeight -
                  headerBlock -
                  footerHeight -
                  gridSpacing * (rowCount - 1))
              .clamp(120.0, double.infinity);
          final cellWidth =
              (width - gridSpacing * (crossAxisCount - 1)) / crossAxisCount;
          final cellHeight = gridHeight / rowCount;
          final aspectRatio = (cellWidth / cellHeight).clamp(0.85, 1.6);

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
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: footerHeight,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _customTableController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 14),
                          decoration: InputDecoration(
                            labelText: LocaleKeys.waiterCustomTable.tr(),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      SizedBox(
                        height: footerHeight,
                        child: ElevatedButton(
                          onPressed: _openCustomTable,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(LocaleKeys.waiterOpenTable.tr()),
                        ),
                      ),
                    ],
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
  const WaiterOrderPage({super.key, required this.tableNumber});

  final int tableNumber;

  @override
  ConsumerState<WaiterOrderPage> createState() => _WaiterOrderPageState();
}

class _WaiterOrderPageState extends ConsumerState<WaiterOrderPage> {
  static const _menuGridSpacing = 4.0;
  static const _categoryBarHeight = 34.0;
  static const _minMenuCellHeightOps = 56.0;
  static const _minMenuCellHeightMobile = 76.0;

  double get _minMenuCellHeight => PlatformLayout.isOpsDesktop
      ? _minMenuCellHeightOps
      : _minMenuCellHeightMobile;

  final _noteController = TextEditingController();
  var _submitting = false;
  var _preparationTags = <String>{};
  ProductCategory _category = ProductCategory.tost;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
    });
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
    final cart = ref.read(waiterCartProvider);
    if (auth == null || branch == null) return;
    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.waiterCartEmpty.tr())),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final note = _noteController.text.trim();
      final orderTotal =
          ref.read(waiterCartProvider.notifier).total(products);
      final waiterCode = waiterReceiptCode(
        username: auth.user.username,
        name: auth.user.name,
      );
      await ref.read(ordersProvider.notifier).placeDineInOrder(
            items: ref.read(waiterCartProvider.notifier).toCartItems(products),
            totalAmount: orderTotal,
            branchId: branch.id,
            tableNumber: widget.tableNumber,
            waiterId: auth.user.id,
            waiterName: auth.user.name,
            waiterCode: waiterCode,
            orderNote: note.isEmpty ? null : note,
            preparationTags: _preparationTags.toList(),
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

  void _onProductTap(Product product) {
    ref.read(waiterCartProvider.notifier).addProduct(product);
  }

  int _menuCrossAxisCount(double width) {
    final dense = PlatformLayout.isOpsDesktop;
    if (dense) {
      if (width >= 1100) return 10;
      if (width >= 900) return 8;
      if (width >= 720) return 7;
      if (width >= 520) return 6;
      return 5;
    }
    if (width >= 720) return 6;
    if (width >= 540) return 5;
    if (width >= 400) return 4;
    return 3;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(opsBranchProductsProvider);
    final cart = ref.watch(waiterCartProvider);
    final products = ref.watch(waiterBranchProductsProvider);
    final total = ref.read(waiterCartProvider.notifier).total(products);

    final mainProducts = products.where((p) {
      if (!p.isAvailable) return false;
      if (_category == ProductCategory.combo) {
        return p.isCombo || p.category == ProductCategory.combo;
      }
      return p.category == _category;
    }).toList();
    final denseMenu = PlatformLayout.isOpsDesktop;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          LocaleKeys.waiterTableOrderTitle.tr(
            namedArgs: {'table': '${widget.tableNumber}'},
          ),
          style: const TextStyle(fontSize: 17),
        ),
        toolbarHeight: 48,
        actions: [
          TextButton.icon(
            onPressed: () =>
                context.push(RoutePaths.branchWaiterBill(widget.tableNumber)),
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
          SizedBox(
            height: _categoryBarHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              children: [
                _CategoryChip(
                  label: LocaleKeys.customerCategoryTost.tr(),
                  selected: _category == ProductCategory.tost,
                  onTap: () =>
                      setState(() => _category = ProductCategory.tost),
                ),
                _CategoryChip(
                  label: LocaleKeys.customerCategorySahanda.tr(),
                  selected: _category == ProductCategory.sahanda,
                  onTap: () =>
                      setState(() => _category = ProductCategory.sahanda),
                ),
                _CategoryChip(
                  label: LocaleKeys.customerCategoryCombo.tr(),
                  selected: _category == ProductCategory.combo,
                  onTap: () =>
                      setState(() => _category = ProductCategory.combo),
                ),
              ],
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: const Color(0xFFF3F4F6),
              child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) =>
                  Center(child: Text(LocaleKeys.commonError.tr())),
              data: (_) {
                if (mainProducts.isEmpty) {
                  return Center(child: Text(LocaleKeys.waiterAddonsEmpty.tr()));
                }
                if (!PlatformLayout.isOpsDesktop) {
                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.xs,
                      AppSpacing.sm,
                      AppSpacing.sm,
                    ),
                    itemCount: mainProducts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final product = mainProducts[index];
                      final qty = cart
                          .where((item) => item.product?.id == product.id)
                          .fold<int>(0, (sum, item) => sum + item.quantity);
                      return _WaiterMobileProductCard(
                        product: product,
                        quantity: qty,
                        onTap: () => _onProductTap(product),
                        onIncrement: () {
                          ref
                              .read(waiterCartProvider.notifier)
                              .addProduct(product);
                        },
                        onDecrement: () {
                          ref
                              .read(waiterCartProvider.notifier)
                              .decrementProduct(product);
                        },
                      );
                    },
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    const hPad = AppSpacing.sm;
                    final width = constraints.maxWidth - hPad * 2;
                    final crossAxisCount = _menuCrossAxisCount(width);
                    final itemCount = mainProducts.length;
                    final rowCount =
                        (itemCount + crossAxisCount - 1) ~/ crossAxisCount;
                    final gridHeight = constraints.maxHeight;
                    final cellWidth = (width -
                            _menuGridSpacing * (crossAxisCount - 1)) /
                        crossAxisCount;
                    final computedCellHeight = rowCount == 0
                        ? gridHeight
                        : (gridHeight - _menuGridSpacing * (rowCount - 1)) /
                            rowCount;
                    var aspectRatio =
                        (cellWidth / computedCellHeight).clamp(0.55, 1.05);
                    var actualCellHeight = cellWidth / aspectRatio;
                    var totalContentHeight = rowCount * actualCellHeight +
                        _menuGridSpacing * (rowCount > 0 ? rowCount - 1 : 0);
                    final needsScroll =
                        totalContentHeight > gridHeight + 0.5 ||
                        computedCellHeight < _minMenuCellHeight;
                    if (needsScroll) {
                      aspectRatio =
                          (cellWidth / _minMenuCellHeight).clamp(0.55, 1.05);
                      actualCellHeight = cellWidth / aspectRatio;
                      totalContentHeight = rowCount * actualCellHeight +
                          _menuGridSpacing * (rowCount > 0 ? rowCount - 1 : 0);
                    }

                    return GridView.builder(
                      physics: needsScroll
                          ? (PlatformLayout.isOpsDesktop
                              ? const ClampingScrollPhysics()
                              : const BouncingScrollPhysics())
                          : const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        hPad,
                        AppSpacing.xs,
                        hPad,
                        AppSpacing.xs,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: _menuGridSpacing,
                        crossAxisSpacing: _menuGridSpacing,
                        childAspectRatio: aspectRatio,
                      ),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        final product = mainProducts[index];
                        final qty = cart
                            .where((item) => item.product?.id == product.id)
                            .fold<int>(0, (sum, item) => sum + item.quantity);
                        return _MenuProductCard(
                          product: product,
                          quantity: qty,
                          cellWidth: cellWidth,
                          compact: true,
                          dense: denseMenu,
                          ultraCompact: needsScroll && crossAxisCount >= 7,
                          onTap: () => _onProductTap(product),
                          onIncrement: () {
                            ref
                                .read(waiterCartProvider.notifier)
                                .addProduct(product);
                          },
                          onDecrement: () {
                            ref
                                .read(waiterCartProvider.notifier)
                                .decrementProduct(product);
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
            ),
          ),
          _WaiterOrderActionBar(
            cart: cart,
            total: total,
            submitting: _submitting,
            preparationTags: _preparationTags.toList(),
            orderNote: _noteController.text.trim(),
            onAddExtras: () => showWaiterAddonsSheet(context, ref),
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
    required this.onAddExtras,
    required this.onEditNote,
    required this.onPreparationTags,
    required this.onSubmit,
  });

  final List<WaiterCartItem> cart;
  final double total;
  final bool submitting;
  final List<String> preparationTags;
  final String orderNote;
  final VoidCallback onAddExtras;
  final VoidCallback onEditNote;
  final VoidCallback onPreparationTags;
  final VoidCallback onSubmit;

  bool get hasNote => orderNote.isNotEmpty;
  int get preparationTagCount => preparationTags.length;

  @override
  Widget build(BuildContext context) {
    final itemCount =
        cart.fold<int>(0, (sum, item) => sum + item.quantity);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.sm,
          AppSpacing.xs,
          AppSpacing.sm,
          AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.divider.withValues(alpha: 0.6)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _FooterIconButton(
                  icon: Icons.local_drink_outlined,
                  label: LocaleKeys.waiterAddDrinksSnacks.tr(),
                  onTap: onAddExtras,
                ),
                const SizedBox(width: 6),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
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
                            child: WaiterPreparationTagsChips(
                              tags: preparationTags,
                              compact: true,
                            ),
                          ),
                        ),
                      ),
                    if (hasNote) ...[
                      if (preparationTags.isNotEmpty)
                        const SizedBox(height: 6),
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
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: submitting || cart.isEmpty ? null : onSubmit,
                style: FilledButton.styleFrom(
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
                              LocaleKeys.waiterCreateOrder.tr(),
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

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: PlatformLayout.isOpsDesktop ? 11 : 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selected: selected,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _WaiterMobileProductCard extends StatelessWidget {
  const _WaiterMobileProductCard({
    required this.product,
    required this.quantity,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
  });

  final Product product;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    final selected = quantity > 0;

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.06)
          : Colors.white,
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black12,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.divider.withValues(alpha: 0.75),
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: ProductThumbnail.fromProduct(
                    product: product,
                    width: 84,
                    height: 84,
                    borderRadius: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedOrRaw(product.nameKey),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      FormatUtils.currency(product.price),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _MobileQtyStepper(
                quantity: quantity,
                onIncrement: onIncrement,
                onDecrement: onDecrement,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileQtyStepper extends StatelessWidget {
  const _MobileQtyStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    if (quantity <= 0) {
      return Material(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onIncrement,
          borderRadius: BorderRadius.circular(10),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.add, color: AppColors.primary),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onIncrement,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            child: const SizedBox(
              width: 44,
              height: 32,
              child: Icon(Icons.add, size: 20, color: Colors.white),
            ),
          ),
          Text(
            '$quantity',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              height: 1,
            ),
          ),
          InkWell(
            onTap: onDecrement,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(10)),
            child: const SizedBox(
              width: 44,
              height: 32,
              child: Icon(Icons.remove, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuProductCard extends StatelessWidget {
  const _MenuProductCard({
    required this.product,
    required this.quantity,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
    this.cellWidth = 120,
    this.compact = false,
    this.dense = false,
    this.ultraCompact = false,
  });

  final Product product;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final double cellWidth;
  final bool compact;
  final bool dense;
  final bool ultraCompact;

  @override
  Widget build(BuildContext context) {
    final nameSize = dense
        ? (cellWidth * 0.105).clamp(9.5, 12.0)
        : compact
            ? (cellWidth * 0.13).clamp(11.0, 15.0)
            : 15.0;
    final priceSize = dense
        ? (nameSize * 0.92).clamp(8.5, 11.0)
        : (nameSize * 0.85).clamp(10.0, 13.0);
    final qtySize = dense
        ? (nameSize * 0.95).clamp(9.0, 11.0)
        : (nameSize * 0.9).clamp(10.0, 14.0);
    final padding = dense ? 3.0 : (ultraCompact ? 4.0 : (compact ? 5.0 : 10.0));
    final radius = dense ? 7.0 : (ultraCompact ? 8.0 : (compact ? 9.0 : 16.0));
    final imageAspect = dense ? 1.65 : (compact ? 1.35 : 1.1);
    final stepperHeight = dense ? 24.0 : 30.0;
    final stepperIconSize = dense ? 16.0 : 20.0;
    final selected = quantity > 0;

    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.07)
          : Colors.white,
      elevation: selected ? 1 : 0,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.55)
                  : AppColors.divider.withValues(alpha: 0.7),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: imageAspect,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(radius - 1),
                      ),
                      child: ProductThumbnail.fromProduct(
                        product: product,
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: 0,
                      ),
                    ),
                    if (quantity > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                AppColors.primary.withValues(alpha: 0.92),
                              ],
                            ),
                          ),
                          child: SizedBox(
                            height: stepperHeight,
                            child: Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: onDecrement,
                                    child: Icon(
                                      Icons.remove,
                                      size: stepperIconSize,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$quantity',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: qtySize,
                                    fontWeight: FontWeight.bold,
                                    height: 1,
                                  ),
                                ),
                                Expanded(
                                  child: InkWell(
                                    onTap: onIncrement,
                                    child: Icon(
                                      Icons.add,
                                      size: stepperIconSize,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  padding,
                  padding,
                  padding,
                  dense ? 2 : padding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedOrRaw(product.nameKey),
                      maxLines: dense ? 2 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: nameSize,
                        height: 1.1,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: dense ? 2 : 3),
                    Text(
                      FormatUtils.currency(product.price),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: priceSize,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
