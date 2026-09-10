import '../../features/waiter/domain/waiter_pos_catalog.dart';
import '../../shared/domain/entities/product.dart';
import '../../shared/domain/entities/waiter_mode_settings.dart';

/// Garson POS bölümü → canlı katalog kategorisi.
ProductCategory waiterPosCategoryFor(WaiterPosSection section) =>
    WaiterPosCatalog.categoryFor(section);

/// Kasa/admin ile aynı ürün listesinden bölüm filtresi.
List<Product> waiterPosProductsForSection(
  List<Product> products,
  WaiterPosSection section,
) {
  return products.where((product) {
    if (!product.isAvailable) return false;
    if (section == WaiterPosSection.tostlar) {
      return product.category == ProductCategory.tost ||
          product.category == ProductCategory.combo ||
          product.isCombo;
    }
    return product.category == waiterPosCategoryFor(section);
  }).toList();
}

Map<String, List<WaiterPosNode>> seedWaiterPosCatalog() {
  return {
    for (final section in WaiterPosSection.values)
      section.name: List<WaiterPosNode>.from(
        WaiterPosCatalog.rootsFor(section),
      ),
  };
}

/// Ayarlarda kayıtlı ağaç varsa onu, yoksa varsayılan VEGA ağacını kullan.
List<WaiterPosNode> effectivePosRoots(
  WaiterPosSection section, [
  WaiterModeSettings? settings,
]) {
  final custom = settings?.posCatalog[section.name];
  if (custom != null && custom.isNotEmpty) return custom;
  return WaiterPosCatalog.rootsFor(section);
}

String normalizePosLabel(String raw) {
  const map = {
    'ç': 'c',
    'Ç': 'c',
    'ğ': 'g',
    'Ğ': 'g',
    'ı': 'i',
    'İ': 'i',
    'i': 'i',
    'I': 'i',
    'ö': 'o',
    'Ö': 'o',
    'ş': 's',
    'Ş': 's',
    'ü': 'u',
    'Ü': 'u',
  };
  final buf = StringBuffer();
  for (final ch in raw.split('')) {
    buf.write(map[ch] ?? ch.toLowerCase());
  }
  return buf
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

List<WaiterPosNode> _flattenLeaves(List<WaiterPosNode> nodes) {
  final out = <WaiterPosNode>[];
  void walk(WaiterPosNode n) {
    if (n.isLeaf) {
      out.add(n);
      return;
    }
    for (final c in n.children) {
      walk(c);
    }
  }

  for (final n in nodes) {
    walk(n);
  }
  return out;
}

Set<String> linkedPosProductIds(List<WaiterPosNode> roots) {
  final ids = <String>{};
  void walk(WaiterPosNode n) {
    final pid = n.productId;
    if (pid != null && pid.isNotEmpty) ids.add(pid);
    for (final c in n.children) {
      walk(c);
    }
  }

  for (final r in roots) {
    walk(r);
  }
  return ids;
}

List<WaiterPosNode> insertPosChild({
  required List<WaiterPosNode> roots,
  required List<String> folderIds,
  required WaiterPosNode child,
}) {
  if (folderIds.isEmpty) return [...roots, child];
  return [
    for (final node in roots)
      if (node.id != folderIds.first)
        node
      else if (folderIds.length == 1)
        node.copyWith(children: [...node.children, child])
      else
        node.copyWith(
          children: insertPosChild(
            roots: node.children,
            folderIds: folderIds.sublist(1),
            child: child,
          ),
        ),
  ];
}

List<WaiterPosNode> removePosNode({
  required List<WaiterPosNode> roots,
  required String nodeId,
}) {
  return [
    for (final node in roots)
      if (node.id == nodeId)
        ...<WaiterPosNode>[]
      else
        node.copyWith(
          children: removePosNode(roots: node.children, nodeId: nodeId),
        ),
  ];
}

List<WaiterPosNode> updatePosNode({
  required List<WaiterPosNode> roots,
  required String nodeId,
  required WaiterPosNode Function(WaiterPosNode current) update,
}) {
  return [
    for (final node in roots)
      if (node.id == nodeId)
        update(node)
      else
        node.copyWith(
          children: updatePosNode(
            roots: node.children,
            nodeId: nodeId,
            update: update,
          ),
        ),
  ];
}

String newPosNodeId(String prefix) =>
    '${prefix}_${DateTime.now().millisecondsSinceEpoch}';

/// POS yaprağını canlı ürüne bağla (fiyat/id senkronu).
Product resolveWaiterPosLeafProduct({
  required WaiterPosNode node,
  required List<WaiterPosNode> path,
  required List<Product> liveProducts,
  required ProductCategory category,
}) {
  assert(node.isLeaf);
  final labelParts = [
    for (final p in path) p.label,
    node.label,
  ];
  final displayLabel = labelParts.join(' · ');

  final linkedId = node.productId;
  if (linkedId != null && linkedId.isNotEmpty) {
    for (final product in liveProducts) {
      if (product.id != linkedId) continue;
      return Product(
        id: product.id,
        nameKey: displayLabel,
        descriptionKey: product.descriptionKey,
        // Garson fiyatı POS düğümünde; katalog fiyatı online menüdedir.
        price: node.price ?? product.price,
        // Mutfak filtresi POS bölümüne güvenir; online kategori sapması
        // (ör. yanlış drink) siparişi KDS'den düşürmesin.
        category: category,
        imageUrl: product.imageUrl,
        isAvailable: product.isAvailable,
        isCombo: product.isCombo,
        extras: product.extras,
        extraIds: product.extraIds,
        imageColorValue: product.imageColorValue,
        comboItems: product.comboItems,
        isRecommended: product.isRecommended,
        qrNavCategoryId: product.qrNavCategoryId,
      );
    }
  }

  final candidates = <String>{
    displayLabel,
    node.label,
    labelParts.join(' '),
    if (path.isNotEmpty) '${path.last.label} ${node.label}',
  };

  Product? best;
  var bestScore = 0;
  for (final product in liveProducts) {
    if (!product.isAvailable) continue;
    if (sectionMismatch(product, category)) continue;
    final productNorm = normalizePosLabel(product.nameKey);
    for (final candidate in candidates) {
      final candNorm = normalizePosLabel(candidate);
      if (candNorm.isEmpty || productNorm.isEmpty) continue;
      var score = 0;
      if (candNorm == productNorm) {
        score = 100;
      } else if (productNorm.contains(candNorm) ||
          candNorm.contains(productNorm)) {
        score = 60 +
            (candNorm.length < productNorm.length
                ? candNorm.length
                : productNorm.length);
      }
      if (score > bestScore) {
        bestScore = score;
        best = product;
      }
    }
  }

  if (best != null && bestScore >= 60) {
    return Product(
      id: best.id,
      nameKey: displayLabel,
      descriptionKey: best.descriptionKey,
      price: node.price ?? best.price,
      category: category,
      imageUrl: best.imageUrl,
      isAvailable: best.isAvailable,
      isCombo: best.isCombo,
      extras: best.extras,
      extraIds: best.extraIds,
      imageColorValue: best.imageColorValue,
      comboItems: best.comboItems,
      isRecommended: best.isRecommended,
      qrNavCategoryId: best.qrNavCategoryId,
    );
  }

  return Product(
    id: node.id,
    nameKey: displayLabel,
    descriptionKey: displayLabel,
    price: node.price ?? 0,
    category: category,
  );
}

bool sectionMismatch(Product product, ProductCategory category) {
  if (category == ProductCategory.tost) {
    return product.category != ProductCategory.tost &&
        product.category != ProductCategory.combo &&
        !product.isCombo;
  }
  return product.category != category;
}

/// Kök ızgarada POS ağacında olmayan canlı ürünler (kasa eklemeleri).
List<WaiterPosNode> unmatchedLiveProductNodes({
  required List<Product> liveProducts,
  required WaiterPosSection section,
  WaiterModeSettings? settings,
}) {
  final roots = effectivePosRoots(section, settings);
  final linked = linkedPosProductIds(roots);
  final covered = <String>{};
  for (final leaf in _flattenLeaves(roots)) {
    covered.add(normalizePosLabel(leaf.label));
  }
  for (final root in roots) {
    covered.add(normalizePosLabel(root.label));
  }

  final sectionProducts = waiterPosProductsForSection(liveProducts, section);
  final extra = <WaiterPosNode>[];
  for (final product in sectionProducts) {
    if (linked.contains(product.id)) continue;
    final norm = normalizePosLabel(product.nameKey);
    if (norm.isEmpty) continue;
    final already = covered.any(
      (c) => c == norm || c.contains(norm) || norm.contains(c),
    );
    if (already) continue;
    extra.add(
      WaiterPosNode(
        id: product.id,
        label: product.nameKey.toUpperCase(),
        price: product.price,
        productId: product.id,
      ),
    );
  }
  return extra;
}
