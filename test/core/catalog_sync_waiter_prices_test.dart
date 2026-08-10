import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/core/utils/waiter_prices.dart';
import 'package:tostu_sahane/shared/domain/entities/product.dart';
import 'package:tostu_sahane/shared/domain/entities/waiter_mode_settings.dart';

void main() {
  test('waiter prices apply catalog overrides without mutating base list ids', () {
    const products = [
      Product(
        id: 'p1',
        nameKey: 'Tost',
        descriptionKey: '',
        price: 100,
        category: ProductCategory.tost,
      ),
      Product(
        id: 'p2',
        nameKey: 'Ayran',
        descriptionKey: '',
        price: 40,
        category: ProductCategory.drink,
      ),
    ];
    const settings = WaiterModeSettings(
      productPrices: {'p1': 120},
    );

    final priced = applyWaiterPricesToProducts(products, settings);
    expect(priced[0].price, 120);
    expect(priced[1].price, 40);
    expect(products[0].price, 100);
  });
}
