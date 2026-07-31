import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../../shared/domain/entities/product.dart';
import '../../domain/waiter_pos_catalog.dart';
import '../providers/waiter_cart_provider.dart';

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

  List<WaiterPosNode> get _visibleNodes {
    if (_path.isEmpty) return WaiterPosCatalog.rootsFor(widget.section);
    return _path.last.children;
  }

  String? get _headerTitle => _path.isEmpty ? null : _path.last.label;

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

  void _onNodeTap(WaiterPosNode node) {
    if (node.isFolder) {
      _openFolder(node);
      return;
    }
    if (!node.isLeaf) return;
    final category = WaiterPosCatalog.categoryFor(widget.section);
    final labelParts = [
      for (final p in _path) p.label,
      node.label,
    ];
    final displayLabel = labelParts.join(' · ');
    final product = Product(
      id: node.id,
      nameKey: displayLabel,
      descriptionKey: displayLabel,
      price: node.price!,
      category: category,
    );
    ref.read(waiterCartProvider.notifier).addProduct(product);
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(waiterCartProvider);
    // Mobil ve Windows aynı POS yoğunluğu (Windows referans).
    final screenW = MediaQuery.sizeOf(context).width;
    final sidebarWidth = screenW < 360 ? 88.0 : 108.0;
    final nodes = _visibleNodes;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ColoredBox(
            color: const Color(0xFFF7F8FA),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_headerTitle != null)
                  Container(
                    color: WaiterPosMenuPanel.headerBlue,
                    padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _closeLevel,
                          tooltip: LocaleKeys.waiterPosClose.tr(),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.15),
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _headerTitle!.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        // Balance the back button so the title stays centered.
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                Expanded(
                  child: nodes.isEmpty
                      ? Center(child: Text(LocaleKeys.waiterAddonsEmpty.tr()))
                      : _buildItemGrid(
                          count: nodes.length,
                          builder: (index, fit) {
                            final node = nodes[index];
                            final qty = !node.isLeaf
                                ? 0
                                : cart
                                    .where(
                                      (item) => item.product?.id == node.id,
                                    )
                                    .fold<int>(
                                      0,
                                      (sum, item) => sum + item.quantity,
                                    );
                            return WaiterPosProductTile(
                              title: node.label,
                              price: node.price,
                              quantity: qty,
                              isFolder: node.isFolder,
                              cellWidth: fit.cellWidth,
                              dense: true,
                              onTap: () => _onNodeTap(node),
                              onIncrement: !node.isLeaf
                                  ? () {}
                                  : () => _onNodeTap(node),
                              onDecrement: !node.isLeaf
                                  ? () {}
                                  : () {
                                      final matching = cart
                                          .where(
                                            (item) =>
                                                item.product?.id == node.id,
                                          )
                                          .toList();
                                      if (matching.isEmpty) return;
                                      final line = matching.last;
                                      ref
                                          .read(waiterCartProvider.notifier)
                                          .setQuantity(
                                            line.lineKey,
                                            line.quantity - 1,
                                          );
                                    },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
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
  }) {
    const pad = 6.0;
    const spacing = 3.0;
    const minTap = 42.0;
    final w = math.max(80.0, width - pad * 2);
    final h = math.max(80.0, height - pad * 2);
    if (count <= 0) {
      return const _GridFit(
        cols: 3,
        aspect: 1.2,
        spacing: spacing,
        cellWidth: 100,
        fits: true,
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
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fit = _computeFit(
          count: count,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
        );
        // Windows ile aynı: sığınca kaydırma yok; sığmazsa kaydır.
        final physics = fit.fits
            ? const NeverScrollableScrollPhysics()
            : const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              );

        return GridView.builder(
          physics: physics,
          padding: const EdgeInsets.all(6),
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
            constraints: const BoxConstraints(minHeight: 56),
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
  });

  final String title;
  final double? price;
  final int quantity;
  final bool isFolder;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final double cellWidth;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final selected = !isFolder && quantity > 0;
    final nameSize = (cellWidth * (dense ? 0.125 : 0.14)).clamp(10.5, 18.0);
    final priceSize = (nameSize * 0.92).clamp(10.0, 16.0);
    final pad = dense ? 5.0 : 8.0;
    final radius = BorderRadius.circular(8);

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
                        alignment: Alignment.center,
                        child: Text(
                          title.toUpperCase(),
                          textAlign: TextAlign.center,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: nameSize,
                            height: 1.05,
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
                              '×$quantity',
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
                                color: AppColors.primary,
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
                              child: _SideHint(
                                icon: Icons.remove,
                                color: AppColors.error.withValues(alpha: 0.85),
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
