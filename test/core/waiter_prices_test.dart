import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/utils/waiter_prices.dart';
import 'package:tostu_sahane/shared/domain/entities/product.dart';
import 'package:tostu_sahane/shared/domain/entities/waiter_mode_settings.dart';

void main() {
  test('uses override when set', () {
    expect(
      resolveWaiterPrice('p1', 100, const {'p1': 85}),
      85,
    );
  });

  test('falls back to catalog price when override missing', () {
    expect(resolveWaiterPrice('p1', 100, const {}), 100);
  });

  test('applyWaiterPricesToProducts updates list', () {
    const product = Product(
      id: 'ts_test',
      nameKey: 'product_test',
      descriptionKey: 'product_test_desc',
      price: 120,
      category: ProductCategory.tost,
    );
    const settings = WaiterModeSettings(
      productPrices: {'ts_test': 99},
    );

    final priced = applyWaiterPricesToProducts([product], settings);
    expect(priced.single.price, 99);
  });
}
