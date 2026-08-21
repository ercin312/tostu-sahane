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

  test('waiter POS sections mirror live catalog categories and prices', () {
    final tostlar =
        waiterPosProductsForSection(catalog, WaiterPosSection.tostlar);
    expect(tostlar.map((p) => p.id), ['p_tost', 'p_combo']);
    expect(tostlar.first.price, 180);

    final drinks =
        waiterPosProductsForSection(catalog, WaiterPosSection.icecekler);
    expect(drinks.single.id, 'p_ayran');
    expect(drinks.single.price, 40);

    final sides =
        waiterPosProductsForSection(catalog, WaiterPosSection.yanUrunler);
    expect(sides.single.id, 'p_patates');

    final sahan =
        waiterPosProductsForSection(catalog, WaiterPosSection.sahan);
    expect(sahan.single.id, 'p_sahan');
  });

  test('unavailable products are excluded from waiter POS', () {
    final tostlar =
        waiterPosProductsForSection(catalog, WaiterPosSection.tostlar);
    expect(tostlar.any((p) => p.id == 'p_hidden'), isFalse);
  });

  test('cashier price change + waiter override resolve for POS tiles', () {
    const settings = WaiterModeSettings(productPrices: {'p_tost': 195});
    final priced = applyWaiterPricesToProducts(catalog, settings);
    final tostlar =
        waiterPosProductsForSection(priced, WaiterPosSection.tostlar);
    expect(tostlar.firstWhere((p) => p.id == 'p_tost').price, 195);
    expect(tostlar.firstWhere((p) => p.id == 'p_combo').price, 250);
  });
}
