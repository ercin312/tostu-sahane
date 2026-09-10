import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/core/utils/order_kitchen_utils.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';
import 'package:tostu_sahane/shared/domain/entities/product.dart';

Order _orderWithItems(List<CartItem> items, {bool isTableAddon = false}) {
  return Order(
    id: 'o1',
    orderNumber: 1,
    customerId: 'c1',
    customerName: 'Test',
    branchId: 'b1',
    items: items,
    totalAmount: 10,
    status: OrderStatus.preparing,
    createdAt: DateTime(2026, 1, 1),
    address: 'addr',
    paymentMethod: PaymentMethod.cashOnDelivery,
    orderType: OrderType.dineIn,
    isTableAddon: isTableAddon,
  );
}

void main() {
  test('hasKitchenItems is false for drink-only extras', () {
    final order = _orderWithItems(
      const [
        CartItem(
          id: '1',
          productId: 'extra_ayran',
          productNameKey: 'Ayran',
          unitPrice: 5,
          quantity: 2,
          productCategory: 'drink',
        ),
      ],
      isTableAddon: true,
    );
    expect(order.hasKitchenItems, isFalse);
    expect(orderHasKitchenItems(order), isFalse);
  });

  test('hasKitchenItems is false for POS drink products', () {
    final order = _orderWithItems(
      const [
        CartItem(
          id: '1',
          productId: 'ts_ayran',
          productNameKey: 'Ayran',
          unitPrice: 40,
          quantity: 1,
          productCategory: 'drink',
        ),
      ],
      isTableAddon: true,
    );
    expect(order.hasKitchenItems, isFalse);
  });

  test('hasKitchenItems is true when food item present', () {
    final order = _orderWithItems(
      const [
        CartItem(
          id: '1',
          productId: 'extra_ayran',
          productNameKey: 'Ayran',
          unitPrice: 5,
          quantity: 1,
          productCategory: 'drink',
        ),
        CartItem(
          id: '2',
          productId: 'ts_1',
          productNameKey: 'Tost',
          unitPrice: 50,
          quantity: 1.5,
          productCategory: 'tost',
        ),
      ],
      isTableAddon: true,
    );
    expect(order.hasKitchenItems, isTrue);
    expect(kitchenCartItems(order).single.productId, 'ts_1');
  });

  test('POS section category beats wrong catalog drink link', () {
    // Garson tost bölümünden girilmiş; canlı katalog yanlışlıkla drink olsa bile
    // product_category=tost → mutfağa düşmeli.
    final order = _orderWithItems(
      const [
        CartItem(
          id: '1',
          productId: 'p_wrong',
          productNameKey: 'Kaşarlı Tost',
          unitPrice: 120,
          quantity: 1,
          productCategory: 'tost',
        ),
      ],
      isTableAddon: true,
    );
    const catalog = [
      Product(
        id: 'p_wrong',
        nameKey: 'Kaşarlı Tost',
        descriptionKey: '',
        price: 120,
        category: ProductCategory.drink,
      ),
    ];
    expect(order.hasKitchenItems, isTrue);
    expect(orderHasKitchenItems(order, catalog: catalog), isTrue);
  });

  test('catalog lookup excludes drink without productCategory', () {
    const catalog = [
      Product(
        id: 'p_ayran',
        nameKey: 'Ayran',
        descriptionKey: '',
        price: 40,
        category: ProductCategory.drink,
      ),
    ];
    final order = _orderWithItems(
      const [
        CartItem(
          id: '1',
          productId: 'p_ayran',
          productNameKey: 'Ayran',
          unitPrice: 40,
          quantity: 1,
        ),
      ],
      isTableAddon: true,
    );
    expect(orderHasKitchenItems(order, catalog: catalog), isFalse);
  });
}
