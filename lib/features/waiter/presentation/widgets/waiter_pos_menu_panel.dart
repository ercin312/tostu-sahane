import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../core/utils/waiter_pos_catalog_utils.dart';
import '../../../../shared/domain/entities/product.dart';
import '../../../../shared/domain/entities/waiter_mode_settings.dart';
import '../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../domain/waiter_pos_catalog.dart';
import '../providers/waiter_cart_provider.dart';
import '../providers/waiter_products_provider.dart';

class _GridFit {
  const _GridFit({
    required this.cols,
    required this.aspect,
    required this.spacing,
    required this.cellWidth,
    required this.fits,
  });

  final int cols;
  final double aspect;
  final double spacing;
  final double cellWidth;
  final bool fits;
}

/// POS: sağ kategori + orta ızgara; klasöre tıklayınca alt seviye (KAPAT ile geri).
/// Yapı VEGA görsellerindeki gibi; fiyat/id mümkünse canlı katalogdan.
class WaiterPosMenuPanel extends ConsumerStatefulWidget {
  const WaiterPosMenuPanel({
    super.key,
    required this.section,
    required this.onSectionChanged,
  });

  final WaiterPosSection section;
  final ValueChanged<WaiterPosSection> onSectionChanged;

  static const tileBlue = Color(0xFFD6E4F0);
  static const tileSelected = Color(0xFFFFF3B0);
  static const sidebarIdle = Color(0xFFD0D7E0);
  static const headerBlue = Color(0xFF1E5FA8);
  static const priceRed = Color(0xFFD32F2F);
  static const closeBar = Color(0xFF3A3F46);

  @override
  ConsumerState<WaiterPosMenuPanel> createState() => _WaiterPosMenuPanelState();
}

class _WaiterPosMenuPanelState extends ConsumerState<WaiterPosMenuPanel> {
  /// Açık klasör yolu (boş = kök ızgara).
  final List<WaiterPosNode> _path = [];

  @override
  void didUpdateWidget(covariant WaiterPosMenuPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _path.clear();
    }
  }

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

  List<WaiterPosNode> _visibleNodes(
    List<Product> liveProducts,
    WaiterModeSettings? settings,
  ) {
    final roots = effectivePosRoots(widget.section, settings);
    final path = _resolvedPath(roots);
    if (path.length != _path.length && _path.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _path
            ..clear()
            ..addAll(path);
        });
      });
    }
    if (path.isNotEmpty) return path.last.children;
    final extras = unmatchedLiveProductNodes(
      liveProducts: liveProducts,
      section: widget.section,
      settings: settings,
    );
    if (extras.isEmpty) return roots;
    return [...roots, ...extras];
  }

  String? _headerTitle(WaiterModeSettings? settings) {
    final roots = effectivePosRoots(widget.section, settings);
    final path = _resolvedPath(roots);
    return path.isEmpty ? null : path.last.label;
  }

  List<WaiterPosNode> _currentPath(WaiterModeSettings? settings) {
    return _resolvedPath(effectivePosRoots(widget.section, settings));
  }

  void _openFolder(WaiterPosNode node) {
    setState(() => _path.add(node));
  }

  void _closeLevel() {
    if (_path.isEmpty) return;
    setState(() => _path.removeLast());
  }

  void _selectSection(WaiterPosSection section) {
    _path.clear();
    widget.onSectionChanged(section);
  }

  Product _productForLeaf(
    WaiterPosNode node,
    List<Product> liveProducts,
    WaiterModeSettings? settings,
  ) {
    return resolveWaiterPosLeafProduct(
      node: node,
      path: _currentPath(settings),
      liveProducts: liveProducts,
      category: WaiterPosCatalog.categoryFor(widget.section),
    );
  }

  void _onNodeTap(
    WaiterPosNode node,
    List<Product> liveProducts,
    WaiterModeSettings? settings,
  ) {
    if (node.isFolder) {
      _openFolder(node);
      return;
    }
    if (!node.isLeaf) return;
    final product = _productForLeaf(node, liveProducts, settings);
    ref.read(waiterCartProvider.notifier).addProduct(product);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(waiterCartProvider);
    final liveProducts = ref.watch(waiterBranchProductsProvider);
    final settings = ref.watch(waiterModeSettingsProvider).valueOrNull;
    final screenW = MediaQuery.sizeOf(context).width;
    final compactPhone = screenW < 520;
    final sidebarWidth = compactPhone ? 0.0 : (screenW < 360 ? 88.0 : 108.0);
    final nodes = _visibleNodes(liveProducts, settings);
    final headerTitle = _headerTitle(settings);

    final inFolder = _path.isNotEmpty;
    final showFolderChrome = headerTitle != null || (compactPhone && inFolder);

    final gridArea = ColoredBox(
      color: const Color(0xFFF7F8FA),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showFolderChrome)
            Container(
              color: WaiterPosMenuPanel.headerBlue,
              padding: EdgeInsets.fromLTRB(
                compactPhone && inFolder ? 4 : 12,
                compactPhone ? 4 : 10,
                12,
                compactPhone ? 4 : 10,
              ),
              child: Row(
                children: [
                  if (compactPhone && inFolder)
                    IconButton(
                      onPressed: _closeLevel,
                      tooltip: LocaleKeys.waiterPosClose.tr(),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      (headerTitle ?? '').toUpperCase(),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: compactPhone ? 14 : 18,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  if (compactPhone && inFolder)
                    const SizedBox(width: 36),
                ],
              ),
            ),
          Expanded(
            child: nodes.isEmpty
                ? Center(child: Text(LocaleKeys.waiterAddonsEmpty.tr()))
                : _buildItemGrid(
                    count: nodes.length,
                    compactPhone: compactPhone,
                    builder: (index, fit) {
                      final node = nodes[index];
                      final product = node.isLeaf
                          ? _productForLeaf(
                              node,
                              liveProducts,
                              settings,
                            )
                          : null;
                      final qty = product == null
                          ? 0.0
                          : cart
                              .where(
                                (item) => item.product?.id == product.id,
                              )
                              .fold<double>(
                                0,
                                (sum, item) => sum + item.quantity,
                              );
                      final unitPrice = node.price ?? product?.price;
                      final halfOk = product != null &&
                          ref
                              .read(waiterCartProvider.notifier)
                              .allowsHalfQuantity(product);
                      return WaiterPosProductTile(
                        title: node.label,
                        price: unitPrice == null
                            ? null
                            : qty > 0
                                ? unitPrice * qty
                                : unitPrice,
                        quantity: qty,
                        isFolder: node.isFolder,
                        cellWidth: fit.cellWidth,
                        dense: !compactPhone,
                        readable: compactPhone,
                        showHalfHint: halfOk &&
                            qty > 0 &&
                            (qty - 1).abs() < 0.001,
                        onTap: () => _onNodeTap(node, liveProducts, settings),
                        onIncrement: product == null
                            ? () {}
                            : () => ref
                                .read(waiterCartProvider.notifier)
                                .addProduct(product),
                        onDecrement: product == null
                            ? () {}
                            : () => ref
                                .read(waiterCartProvider.notifier)
                                .decrementProduct(product),
                      );
                    },
                  ),
          ),
          // Masaüstü/tablet: KAPAT bar (VEGA). Telefonda geri ok üst başlıkta.
          if (!compactPhone && inFolder)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _closeLevel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: WaiterPosMenuPanel.closeBar,
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    LocaleKeys.waiterPosClose.tr().toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (compactPhone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: gridArea),
          _MobileCategoryBar(
            section: widget.section,
            onSectionChanged: _selectSection,
            sectionLabel: _sectionLabel,
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: gridArea),
        SizedBox(
          width: sidebarWidth,
          child: ColoredBox(
            color: const Color(0xFFE9EEF3),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
              children: [
                for (final section in WaiterPosSection.values)
                  _SidebarButton(
                    label: _sectionLabel(section),
                    selected: widget.section == section,
                    onTap: () => _selectSection(section),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _sectionLabel(WaiterPosSection section) => switch (section) {
        WaiterPosSection.tostlar => LocaleKeys.waiterPosTostlar.tr(),
        WaiterPosSection.sahan => LocaleKeys.waiterPosSahan.tr(),
        WaiterPosSection.icecekler => LocaleKeys.waiterPosIcecekler.tr(),
        WaiterPosSection.yanUrunler => LocaleKeys.waiterPosYanUrunler.tr(),
      };

  static _GridFit _computeFit({
    required int count,
    required double width,
    required double height,
    bool compactPhone = false,
  }) {
    final pad = compactPhone ? 4.0 : 6.0;
    final spacing = compactPhone ? 5.0 : 3.0;
    final minTap = compactPhone ? 70.0 : 42.0;
    final w = math.max(80.0, width - pad * 2);
    final h = math.max(80.0, height - pad * 2);
    if (count <= 0) {
      return _GridFit(
        cols: compactPhone ? 3 : 3,
        aspect: compactPhone ? 1.15 : 1.2,
        spacing: spacing,
        cellWidth: 100,
        fits: !compactPhone,
      );
    }

    // Telefon: 3 sütun (dar ekranda 2), daha kısa kutular + kaydırma.
    if (compactPhone) {
      final cols = count == 1
          ? 1
          : (w >= 340 && count >= 3)
              ? 3
              : 2;
      final cellW = (w - spacing * (cols - 1)) / cols;
      // Geniş > yüksek → daha çok satır sığar, isimler hâlâ okunur.
      final targetH = math.max(minTap, cellW * 0.78);
      return _GridFit(
        cols: cols,
        aspect: (cellW / targetH).clamp(1.0, 1.45),
        spacing: spacing,
        cellWidth: cellW,
        fits: false,
      );
    }

    _GridFit? bestFit;
    double bestScore = -1;

    final maxCols = math.min(count, 8);
    for (var cols = maxCols; cols >= 2; cols--) {
      final rows = (count + cols - 1) ~/ cols;
      final cellW = (w - spacing * (cols - 1)) / cols;
      final cellH = (h - spacing * (rows - 1)) / rows;
      if (cellH < minTap) continue;
      final aspect = cellW / cellH;
      final score =
          cellH * 2 + (aspect >= 0.75 && aspect <= 2.6 ? 40 : 0) + cols;
      if (score > bestScore) {
        bestScore = score;
        bestFit = _GridFit(
          cols: cols,
          aspect: aspect.clamp(0.55, 2.9),
          spacing: spacing,
          cellWidth: cellW,
          fits: true,
        );
      }
    }

    if (bestFit != null) return bestFit;

    final cols = math.min(count, 6);
    final rows = (count + cols - 1) ~/ cols;
    final cellW = (w - spacing * (cols - 1)) / cols;
    final targetH = math.max(minTap, h / math.max(rows, 1));
    return _GridFit(
      cols: cols,
      aspect: (cellW / targetH).clamp(0.55, 2.2),
      spacing: spacing,
      cellWidth: cellW,
      fits: false,
    );
  }

  Widget _buildItemGrid({
    required int count,
    required Widget Function(int index, _GridFit fit) builder,
    bool compactPhone = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = _computeFit(
          count: count,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          compactPhone: compactPhone,
        );
        final physics = fit.fits
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              );

        return GridView.builder(
          physics: physics,
          padding: EdgeInsets.all(compactPhone ? 4 : 6),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: fit.cols,
            mainAxisSpacing: fit.spacing,
            crossAxisSpacing: fit.spacing,
            childAspectRatio: fit.aspect,
          ),
          itemCount: count,
          itemBuilder: (context, index) => builder(index, fit),
        );
      },
    );
  }
}

class _MobileCategoryBar extends StatelessWidget {
  const _MobileCategoryBar({
    required this.section,
    required this.onSectionChanged,
    required this.sectionLabel,
  });

  final WaiterPosSection section;
  final ValueChanged<WaiterPosSection> onSectionChanged;
  final String Function(WaiterPosSection) sectionLabel;

  @override
  Widget build(BuildContext context) {
    // SafeArea yok: alt sipariş çubuğu zaten inset alıyor; çift boşluk oluşmasın.
    return ColoredBox(
      color: const Color(0xFFE9EEF3),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          itemCount: WaiterPosSection.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 4),
          itemBuilder: (context, index) {
            final item = WaiterPosSection.values[index];
            final selected = section == item;
            return Material(
              color: selected
                  ? AppColors.success
                  : WaiterPosMenuPanel.sidebarIdle,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => onSectionChanged(item),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  constraints: const BoxConstraints(minWidth: 64),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF1B8A4A)
                          : const Color(0xFF8E9AAB),
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    sectionLabel(item).toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      height: 1.0,
                      color: selected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
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
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: selected ? AppColors.success : WaiterPosMenuPanel.sidebarIdle,
        borderRadius: BorderRadius.circular(8),
        elevation: selected ? 1 : 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 52),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color(0xFF1B8A4A)
                    : const Color(0xFF8E9AAB),
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12.5,
                height: 1.05,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WaiterPosProductTile extends StatelessWidget {
  const WaiterPosProductTile({
    super.key,
    required this.title,
    required this.quantity,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
    required this.cellWidth,
    this.price,
    this.isFolder = false,
    this.dense = false,
    this.readable = false,
    this.showHalfHint = false,
  });

  final String title;
  final double? price;
  final double quantity;
  final bool isFolder;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final double cellWidth;
  final bool dense;
  /// Mobil: daha büyük yazı / padding (sıkışık dense grid yerine).
  final bool readable;
  /// Adet 1 iken − tarafında 0,5 ipucu (Windows ile aynı yarım adım).
  final bool showHalfHint;

  @override
  Widget build(BuildContext context) {
    final selected = !isFolder && quantity > 0;
    final nameSize = readable
        ? (cellWidth * 0.14).clamp(12.0, 15.5)
        : (cellWidth * (dense ? 0.125 : 0.14)).clamp(10.5, 18.0);
    final priceSize = readable
        ? (nameSize * 0.9).clamp(11.0, 14.0)
        : (nameSize * 0.92).clamp(10.0, 16.0);
    final pad = readable ? 6.0 : (dense ? 5.0 : 8.0);
    final radius = BorderRadius.circular(readable ? 6 : 8);

    return Material(
      color: selected
          ? WaiterPosMenuPanel.tileSelected
          : WaiterPosMenuPanel.tileBlue,
      borderRadius: radius,
      elevation: selected ? 1 : 0,
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            color: selected
                ? const Color(0xFFC9A227)
                : const Color(0xFF7A8FA3),
            width: selected ? 2 : 1,
          ),
          gradient: selected
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE8F1F8), Color(0xFFC9D9E8)],
                ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: Padding(
                padding: EdgeInsets.fromLTRB(pad, pad, pad, pad - 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: readable
                            ? Alignment.topCenter
                            : Alignment.center,
                        child: Text(
                          title.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: readable ? 3 : 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: nameSize,
                            height: readable ? 1.1 : 1.05,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        if (selected)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFF9AA7B5),
                              ),
                            ),
                            child: Text(
                              '×${formatWaiterQuantity(quantity)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: (nameSize * 0.85).clamp(11, 15),
                              ),
                            ),
                          )
                        else if (isFolder)
                          Icon(
                            Icons.chevron_right,
                            size: (nameSize * 1.1).clamp(14, 20),
                            color: AppColors.textSecondary,
                          )
                        else
                          const SizedBox.shrink(),
                        const Spacer(),
                        if (price != null)
                          Flexible(
                            child: Text(
                              FormatUtils.currency(price!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: WaiterPosMenuPanel.priceRed,
                                fontWeight: FontWeight.w900,
                                fontSize: priceSize,
                                height: 1,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (isFolder || !selected)
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: radius,
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Row(
                  children: [
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onDecrement,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: showHalfHint
                                  ? _HalfQtyHint(compact: readable)
                                  : _SideHint(
                                      icon: Icons.remove,
                                      color: AppColors.error
                                          .withValues(alpha: 0.85),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onIncrement,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: _SideHint(
                                icon: Icons.add,
                                color:
                                    AppColors.success.withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SideHint extends StatelessWidget {
  const _SideHint({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}

/// İlk − : 0,5 (yarım) — mobilde de Windows ile aynı seçenek görünsün.
class _HalfQtyHint extends StatelessWidget {
  const _HalfQtyHint({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.error.withValues(alpha: 0.9);
    return Container(
      constraints: BoxConstraints(
        minWidth: compact ? 40 : 36,
        minHeight: compact ? 36 : 34,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 6,
        vertical: compact ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        '0,5',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: compact ? 13 : 12,
          height: 1,
        ),
      ),
    );
  }
}
