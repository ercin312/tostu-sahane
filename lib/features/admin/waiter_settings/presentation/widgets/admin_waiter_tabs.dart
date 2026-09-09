import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/waiter_pos_catalog_utils.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/product_extra.dart';
import '../../../../../shared/domain/entities/waiter_mode_settings.dart';
import '../../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../../../waiter/domain/waiter_pos_catalog.dart';
import '../../../menu/presentation/widgets/admin_catalog_extras_tab.dart';
import '../../../presentation/providers/admin_provider.dart';

class AdminWaiterMenuTab extends ConsumerStatefulWidget {
  const AdminWaiterMenuTab({super.key});

  @override
  ConsumerState<AdminWaiterMenuTab> createState() => _AdminWaiterMenuTabState();
}

class _AdminWaiterMenuTabState extends ConsumerState<AdminWaiterMenuTab> {
  WaiterPosSection _section = WaiterPosSection.tostlar;
  final List<WaiterPosNode> _path = [];
  var _busy = false;

  List<WaiterPosNode> _roots(WaiterModeSettings settings) =>
      effectivePosRoots(_section, settings);

  List<WaiterPosNode> _resolvedPath(List<WaiterPosNode> roots) {
    final resolved = <WaiterPosNode>[];
    var level = roots;
    for (final step in _path) {
      WaiterPosNode? match;
      for (final n in level) {
        if (n.id == step.id) {
          match = n;
          break;
        }
      }
      if (match == null) break;
      resolved.add(match);
      level = match.children;
    }
    return resolved;
  }

  List<WaiterPosNode> _visible(WaiterModeSettings settings) {
    final roots = _roots(settings);
    final path = _resolvedPath(roots);
    if (path.isNotEmpty) return path.last.children;
    return roots;
  }

  Future<void> _persistCatalog(
    WaiterModeSettings current,
    Map<String, List<WaiterPosNode>> catalog,
  ) async {
    setState(() => _busy = true);
    try {
      await saveWaiterModeSettings(
        ref,
        current.copyWith(posCatalog: catalog),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminWaiterPosSaved.tr())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Map<String, List<WaiterPosNode>> _workingCatalog(WaiterModeSettings s) {
    if (s.posCatalog.isNotEmpty) {
      return {
        for (final e in s.posCatalog.entries) e.key: List.of(e.value),
      };
    }
    return seedWaiterPosCatalog();
  }

  Future<void> _addFolder(WaiterModeSettings settings) async {
    final name = await _promptText(
      title: LocaleKeys.adminWaiterPosAddFolder.tr(),
      label: LocaleKeys.adminWaiterPosFolderName.tr(),
    );
    if (name == null || name.trim().isEmpty) return;
    final catalog = _workingCatalog(settings);
    final folderIds = _resolvedPath(_roots(settings)).map((e) => e.id).toList();
    final node = WaiterPosNode(
      id: newPosNodeId('wf'),
      label: name.trim().toUpperCase(),
    );
    catalog[_section.name] = insertPosChild(
      roots: catalog[_section.name] ?? _roots(settings),
      folderIds: folderIds,
      child: node,
    );
    await _persistCatalog(settings, catalog);
  }

  Product? _linkedProduct(WaiterPosNode node) {
    final linked = node.productId;
    if (linked == null || linked.isEmpty) return null;
    final products = ref.read(adminProductsProvider).value ?? [];
    for (final product in products) {
      if (product.id == linked) return product;
    }
    return null;
  }

  double _waiterPriceOf(WaiterModeSettings settings, WaiterPosNode node) {
    final linked = node.productId;
    if (linked != null && linked.isNotEmpty) {
      final override = settings.productPrices[linked];
      if (override != null && override >= 0) return override;
    }
    return node.price ?? _linkedProduct(node)?.price ?? 0;
  }

  Future<void> _addProduct(WaiterModeSettings settings) async {
    final data = await _promptProduct();
    if (data == null) return;
    setState(() => _busy = true);
    try {
      final category = WaiterPosCatalog.categoryFor(_section);
      final created = await ref.read(adminProductsProvider.notifier).createProduct(
            name: data.name,
            description: data.name,
            price: data.onlinePrice,
            category: category,
          );
      final catalog = _workingCatalog(settings);
      final folderIds =
          _resolvedPath(_roots(settings)).map((e) => e.id).toList();
      final node = WaiterPosNode(
        id: newPosNodeId('wp'),
        label: data.name.toUpperCase(),
        price: data.waiterPrice,
        productId: created.id,
      );
      catalog[_section.name] = insertPosChild(
        roots: catalog[_section.name] ?? _roots(settings),
        folderIds: folderIds,
        child: node,
      );
      final productPrices = Map<String, double>.from(settings.productPrices)
        ..[created.id] = data.waiterPrice;
      await saveWaiterModeSettings(
        ref,
        settings.copyWith(posCatalog: catalog, productPrices: productPrices),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminWaiterPosSaved.tr())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editLeaf(
    WaiterModeSettings settings,
    WaiterPosNode node,
  ) async {
    final existing = _linkedProduct(node);
    final data = await _promptProduct(
      initialName: node.label,
      initialWaiterPrice: _waiterPriceOf(settings, node),
      initialOnlinePrice: existing?.price ?? node.price ?? 0,
    );
    if (data == null) return;
    setState(() => _busy = true);
    try {
      if (existing != null) {
        final nameChanged = existing.nameKey != data.name;
        final onlineChanged = existing.price != data.onlinePrice;
        if (nameChanged || onlineChanged) {
          await ref.read(adminProductsProvider.notifier).updateProduct(
                existing.copyWith(
                  nameKey: data.name,
                  descriptionKey: data.name,
                  price: data.onlinePrice,
                ),
              );
        }
      }
      final catalog = _workingCatalog(settings);
      catalog[_section.name] = updatePosNode(
        roots: catalog[_section.name] ?? _roots(settings),
        nodeId: node.id,
        update: (current) => current.copyWith(
          label: data.name.toUpperCase(),
          price: data.waiterPrice,
        ),
      );
      final productPrices = Map<String, double>.from(settings.productPrices);
      final linked = node.productId;
      if (linked != null && linked.isNotEmpty) {
        productPrices[linked] = data.waiterPrice;
      }
      await saveWaiterModeSettings(
        ref,
        settings.copyWith(posCatalog: catalog, productPrices: productPrices),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminWaiterPosSaved.tr())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteNode(
    WaiterModeSettings settings,
    WaiterPosNode node,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.adminWaiterPosDeleteNode.tr()),
        content: Text(LocaleKeys.adminWaiterPosDeleteNodeConfirm.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(LocaleKeys.commonRemove.tr()),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final catalog = _workingCatalog(settings);
    catalog[_section.name] = removePosNode(
      roots: catalog[_section.name] ?? _roots(settings),
      nodeId: node.id,
    );
    if (_path.any((p) => p.id == node.id)) {
      setState(() => _path.clear());
    }
    await _persistCatalog(settings, catalog);
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(LocaleKeys.commonSave.tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<({String name, double waiterPrice, double onlinePrice})?>
      _promptProduct({
    String initialName = '',
    double initialWaiterPrice = 0,
    double? initialOnlinePrice,
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    final waiterCtrl = TextEditingController(
      text: initialWaiterPrice > 0 ? initialWaiterPrice.toStringAsFixed(0) : '',
    );
    final onlineCtrl = TextEditingController(
      text: (initialOnlinePrice ?? initialWaiterPrice) > 0
          ? (initialOnlinePrice ?? initialWaiterPrice).toStringAsFixed(0)
          : '',
    );
    final result =
        await showDialog<({String name, double waiterPrice, double onlinePrice})>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.adminWaiterPosAddProduct.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminWaiterPosProductName.tr(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: waiterCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: LocaleKeys.adminWaiterPrice.tr(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: onlineCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: LocaleKeys.adminOnlinePrice.tr(),
                helperText: LocaleKeys.adminPriceChannelsHint.tr(),
                helperMaxLines: 3,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final waiterPrice = double.tryParse(
                    waiterCtrl.text.trim().replaceAll(',', '.'),
                  ) ??
                  0;
              final onlinePrice = double.tryParse(
                    onlineCtrl.text.trim().replaceAll(',', '.'),
                  ) ??
                  waiterPrice;
              if (name.isEmpty || waiterPrice < 0 || onlinePrice < 0) return;
              Navigator.pop(
                ctx,
                (
                  name: name,
                  waiterPrice: waiterPrice,
                  onlinePrice: onlinePrice,
                ),
              );
            },
            child: Text(LocaleKeys.commonSave.tr()),
          ),
        ],
      ),
    );
    nameCtrl.dispose();
    waiterCtrl.dispose();
    onlineCtrl.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(waiterModeSettingsProvider);
    ref.watch(adminProductsProvider);

    return settingsAsync.when(
      skipLoadingOnReload: true,
      skipLoadingOnRefresh: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(child: Text(LocaleKeys.commonError.tr())),
      data: (settings) {
        final roots = _roots(settings);
        final path = _resolvedPath(roots);
        final nodes = _visible(settings);
        final header = path.isEmpty ? null : path.last.label;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Text(
                LocaleKeys.adminWaiterMenuTabHint.tr(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ColoredBox(
                      color: const Color(0xFFF7F8FA),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (header != null)
                            Container(
                              color: const Color(0xFF1E5FA8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Text(
                                header.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              itemCount: nodes.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (context, index) {
                                final node = nodes[index];
                                final waiterPrice = node.isFolder
                                    ? null
                                    : _waiterPriceOf(settings, node);
                                final onlinePrice = node.isFolder
                                    ? null
                                    : _linkedProduct(node)?.price;
                                return Material(
                                  color: node.isFolder
                                      ? const Color(0xFFE8F1F8)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  child: ListTile(
                                    isThreeLine: !node.isFolder,
                                    title: Text(
                                      node.label.toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    subtitle: node.isFolder
                                        ? null
                                        : Text(
                                            '${LocaleKeys.adminWaiterPrice.tr()}: ${waiterPrice == null ? '—' : FormatUtils.currency(waiterPrice)}\n'
                                            '${LocaleKeys.adminOnlinePrice.tr()}: ${onlinePrice == null ? '—' : FormatUtils.currency(onlinePrice)}',
                                            style: const TextStyle(
                                              color: Color(0xFFD32F2F),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                    leading: Icon(
                                      node.isFolder
                                          ? Icons.folder_open
                                          : Icons.restaurant_menu,
                                      color: AppColors.primary,
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (node.isLeaf)
                                          IconButton(
                                            tooltip: LocaleKeys.commonEdit.tr(),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            onPressed: _busy
                                                ? null
                                                : () => _editLeaf(
                                                      settings,
                                                      node,
                                                    ),
                                          ),
                                        IconButton(
                                          tooltip: LocaleKeys
                                              .adminWaiterPosDeleteNode
                                              .tr(),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          color: AppColors.error,
                                          onPressed: _busy
                                              ? null
                                              : () => _deleteNode(
                                                    settings,
                                                    node,
                                                  ),
                                        ),
                                        if (node.isFolder)
                                          const Icon(Icons.chevron_right),
                                      ],
                                    ),
                                    onTap: () {
                                      if (node.isFolder) {
                                        setState(() => _path.add(node));
                                      } else {
                                        _editLeaf(settings, node);
                                      }
                                    },
                                  ),
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            child: Row(
                              children: [
                                if (path.isNotEmpty)
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => setState(
                                                () => _path.removeLast(),
                                              ),
                                      child: Text(
                                        LocaleKeys.waiterPosClose
                                            .tr()
                                            .toUpperCase(),
                                      ),
                                    ),
                                  ),
                                if (path.isNotEmpty)
                                  const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _addFolder(settings),
                                    icon: const Icon(Icons.create_new_folder),
                                    label: Text(
                                      LocaleKeys.adminWaiterPosAddFolder.tr(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _busy
                                        ? null
                                        : () => _addProduct(settings),
                                    icon: _busy
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.add),
                                    label: Text(
                                      LocaleKeys.adminWaiterPosAddProduct.tr(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 108,
                    child: ColoredBox(
                      color: const Color(0xFFE9EEF3),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
                        children: [
                          for (final section in WaiterPosSection.values)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Material(
                                color: _section == section
                                    ? AppColors.success
                                    : const Color(0xFFD0D7E0),
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => setState(() {
                                    _section = section;
                                    _path.clear();
                                  }),
                                  child: Container(
                                    constraints:
                                        const BoxConstraints(minHeight: 52),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      _sectionLabel(section).toUpperCase(),
                                      textAlign: TextAlign.center,
                                      maxLines: 3,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 12,
                                        color: _section == section
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _sectionLabel(WaiterPosSection section) => switch (section) {
        WaiterPosSection.tostlar => LocaleKeys.waiterPosTostlar.tr(),
        WaiterPosSection.sahan => LocaleKeys.waiterPosSahan.tr(),
        WaiterPosSection.icecekler => LocaleKeys.waiterPosIcecekler.tr(),
        WaiterPosSection.yanUrunler => LocaleKeys.waiterPosYanUrunler.tr(),
      };
}

class AdminWaiterExtrasTab extends ConsumerWidget {
  const AdminWaiterExtrasTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            0,
          ),
          child: Text(
            LocaleKeys.adminWaiterExtrasTabHint.tr(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
        const Expanded(
          child: AdminCatalogExtrasTab(
            showInlineAddButton: true,
            separateWaiterPrice: true,
            kinds: const [ProductExtraKind.addon],
            defaultKind: ProductExtraKind.addon,
          ),
        ),
      ],
    );
  }
}

class AdminWaiterSortTab extends ConsumerWidget {
  const AdminWaiterSortTab({
    super.key,
    required this.productOrder,
    required this.extraOrder,
    required this.onProductOrderChanged,
    required this.onExtraOrderChanged,
  });

  final List<String> productOrder;
  final List<String> extraOrder;
  final ValueChanged<List<String>> onProductOrderChanged;
  final ValueChanged<List<String>> onExtraOrderChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(adminProductsProvider).value ?? [];
    final extras = ref.watch(adminCatalogExtrasProvider).value ?? [];

    final waiterProducts = products
        .where(
          (p) =>
              p.category == ProductCategory.tost ||
              p.category == ProductCategory.sahanda ||
              p.category == ProductCategory.drink ||
              p.category == ProductCategory.snack ||
              p.isCombo ||
              p.category == ProductCategory.combo,
        )
        .toList();

    List<T> sortIds<T>(
      List<T> items,
      String Function(T) idFor,
      List<String> order,
    ) {
      if (order.isEmpty) return items;
      final indexOf = {for (var i = 0; i < order.length; i++) order[i]: i};
      return [...items]
        ..sort((a, b) {
          final ai = indexOf[idFor(a)];
          final bi = indexOf[idFor(b)];
          if (ai != null && bi != null) return ai.compareTo(bi);
          if (ai != null) return -1;
          if (bi != null) return 1;
          return idFor(a).compareTo(idFor(b));
        });
    }

    final sortedProducts = sortIds(waiterProducts, (p) => p.id, productOrder);
    final sortedExtras = sortIds(extras, (e) => e.id, extraOrder);

    final productIds = sortedProducts.map((p) => p.id).toList();
    final extraIds = sortedExtras.map((e) => e.id).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          LocaleKeys.adminWaiterSortTabHint.tr(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          LocaleKeys.adminWaiterSortProducts.tr(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: productIds.length,
          onReorder: (oldIndex, newIndex) {
            final updated = [...productIds];
            if (newIndex > oldIndex) newIndex -= 1;
            final item = updated.removeAt(oldIndex);
            updated.insert(newIndex, item);
            onProductOrderChanged(updated);
          },
          itemBuilder: (context, index) {
            final product = sortedProducts[index];
            return ListTile(
              key: ValueKey(product.id),
              leading: const Icon(Icons.drag_handle),
              title: Text(product.nameKey),
            );
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          LocaleKeys.adminWaiterSortExtras.tr(),
          style: Theme.of(context).textTheme.titleSmall,
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: extraIds.length,
          onReorder: (oldIndex, newIndex) {
            final updated = [...extraIds];
            if (newIndex > oldIndex) newIndex -= 1;
            final item = updated.removeAt(oldIndex);
            updated.insert(newIndex, item);
            onExtraOrderChanged(updated);
          },
          itemBuilder: (context, index) {
            final extra = sortedExtras[index];
            return ListTile(
              key: ValueKey(extra.id),
              leading: const Icon(Icons.drag_handle),
              title: Text(extra.name),
            );
          },
        ),
      ],
    );
  }
}
