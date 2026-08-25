import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/utils/waiter_pos_catalog_utils.dart';
import 'package:tostu_sahane/core/utils/waiter_prices.dart';
import 'package:tostu_sahane/features/waiter/domain/waiter_pos_catalog.dart';
import 'package:tostu_sahane/shared/domain/entities/product.dart';
import 'package:tostu_sahane/shared/domain/entities/waiter_mode_settings.dart';

void main() {
  const catalog = [
    Product(
      id: 'p_tost',
      nameKey: 'Tost',
      descriptionKey: '',
      price: 180,
      category: ProductCategory.tost,
    ),
    Product(
      id: 'p_akdeniz',
      nameKey: 'Akdeniz Tost',
      descriptionKey: '',
      price: 230,
      category: ProductCategory.tost,
    ),
    Product(
      id: 'p_combo',
      nameKey: 'Combo',
      descriptionKey: '',
      price: 250,
      category: ProductCategory.combo,
      isCombo: true,
    ),
    Product(
      id: 'p_sahan',
      nameKey: 'Sahanda',
      descriptionKey: '',
      price: 200,
      category: ProductCategory.sahanda,
    ),
    Product(
      id: 'p_ayran',
      nameKey: 'Ayran',
      descriptionKey: '',
      price: 40,
      category: ProductCategory.drink,
    ),
    Product(
      id: 'p_patates',
      nameKey: 'Patates',
      descriptionKey: '',
      price: 160,
      category: ProductCategory.snack,
    ),
    Product(
      id: 'p_hidden',
      nameKey: 'Gizli',
      descriptionKey: '',
      price: 99,
      category: ProductCategory.tost,
      isAvailable: false,
    ),
  ];

  test('tostlar has folders and direct leaves', () {
    final roots = WaiterPosCatalog.tostlar;
    final karisik = roots.firstWhere((n) => n.id == 'w_karisik');
    expect(karisik.isFolder, isTrue);
    expect(karisik.children, isNotEmpty);
    expect(karisik.price, isNull);

    final akdeniz = roots.firstWhere((n) => n.id == 'w_akdeniz');
    expect(akdeniz.isLeaf, isTrue);
    expect(akdeniz.price, 220);
  });

  test('insertPosChild places leaf inside folder', () {
    final roots = WaiterPosCatalog.tostlar;
    final updated = insertPosChild(
      roots: roots,
      folderIds: ['w_karisik'],
      child: const WaiterPosNode(
        id: 'wp_new',
        label: 'YENI',
        price: 199,
        productId: 'p_new',
      ),
    );
    final karisik = updated.firstWhere((n) => n.id == 'w_karisik');
    expect(karisik.children.any((c) => c.id == 'wp_new'), isTrue);
  });

  test('linked productId wins over fuzzy name match', () {
    const node = WaiterPosNode(
      id: 'wp_x',
      label: 'OZEL',
      price: 10,
      productId: 'p_akdeniz',
    );
    final resolved = resolveWaiterPosLeafProduct(
      node: node,
      path: const [],
      liveProducts: catalog,
      category: ProductCategory.tost,
    );
    expect(resolved.id, 'p_akdeniz');
    expect(resolved.price, 230);
  });

  test('waiter POS sections mirror live catalog categories and prices', () {
    final tostlar =
        waiterPosProductsForSection(catalog, WaiterPosSection.tostlar);
    expect(tostlar.map((p) => p.id), ['p_tost', 'p_akdeniz', 'p_combo']);
    expect(tostlar.first.price, 180);
  });

  test('live leaf price overrides catalog when name matches', () {
    final node = WaiterPosCatalog.tostlar.firstWhere((n) => n.id == 'w_akdeniz');
    final resolved = resolveWaiterPosLeafProduct(
      node: node,
      path: const [],
      liveProducts: catalog,
      category: ProductCategory.tost,
    );
    expect(resolved.id, 'p_akdeniz');
    expect(resolved.price, 230);
  });

  test('folder leaf keeps catalog price when no live match', () {
    final karisik =
        WaiterPosCatalog.tostlar.firstWhere((n) => n.id == 'w_karisik');
    final sade = karisik.children.firstWhere((n) => n.label == 'SADE');
    final resolved = resolveWaiterPosLeafProduct(
      node: sade,
      path: [karisik],
      liveProducts: catalog,
      category: ProductCategory.tost,
    );
    expect(resolved.id, sade.id);
    expect(resolved.price, 200);
    expect(resolved.nameKey, 'KARISIK · SADE');
  });

  test('unmatched live products append as extra root nodes', () {
    final extras = unmatchedLiveProductNodes(
      liveProducts: catalog,
      section: WaiterPosSection.tostlar,
    );
    expect(extras.any((n) => n.id == 'p_combo'), isTrue);
    expect(extras.any((n) => n.id == 'p_tost'), isFalse);
    expect(extras.any((n) => n.id == 'p_akdeniz'), isFalse);
  });

  test('cashier price change + waiter override resolve for POS tiles', () {
    const settings = WaiterModeSettings(productPrices: {'p_tost': 195});
    final priced = applyWaiterPricesToProducts(catalog, settings);
    final tostlar =
        waiterPosProductsForSection(priced, WaiterPosSection.tostlar);
    expect(tostlar.firstWhere((p) => p.id == 'p_tost').price, 195);
  });

  test('WaiterModeSettings posCatalog round-trip', () {
    final settings = WaiterModeSettings(
      posCatalog: {
        'tostlar': [
          const WaiterPosNode(
            id: 'w_x',
            label: 'X',
            price: 10,
            productId: 'p_x',
          ),
          const WaiterPosNode(
            id: 'w_folder',
            label: 'FOLDER',
            children: [
              WaiterPosNode(id: 'w_y', label: 'Y', price: 20),
            ],
          ),
        ],
      },
    );
    final restored = WaiterModeSettings.fromJson(settings.toJson());
    expect(restored.posCatalog['tostlar']!.length, 2);
    expect(restored.posCatalog['tostlar']!.first.productId, 'p_x');
    expect(restored.posCatalog['tostlar']![1].isFolder, isTrue);
    expect(restored.posCatalog['tostlar']![1].children.single.price, 20);
  });
}
