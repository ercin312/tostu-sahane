import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/core/utils/delivery_fee_utils.dart';
import 'package:tostu_sahane/core/utils/promotion_utils.dart';
import 'package:tostu_sahane/shared/domain/entities/branch.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';
import 'package:tostu_sahane/shared/domain/entities/product.dart';
import 'package:tostu_sahane/shared/domain/entities/promotion_campaign.dart';

void main() {
  const branch = Branch(
    id: 'b1',
    name: 'Test',
    address: 'Addr',
    latitude: 41.0,
    longitude: 29.0,
    baseDeliveryFee: 15,
    freeDeliveryMinOrder: 150,
    deliveryFeePerKm: 5,
    prepTimeMinutes: 15,
  );

  test('global free delivery threshold overrides branch default', () {
    expect(
      DeliveryFeeUtils.calculate(
        branch: branch,
        subtotal: 120,
        freeDeliveryMinOrder: 100,
      ),
      0,
    );
    expect(
      DeliveryFeeUtils.calculate(
        branch: branch,
        subtotal: 80,
        freeDeliveryMinOrder: 100,
      ),
      greaterThan(0),
    );
  });

  test('percent promotion applies above minimum', () {
    const campaign = PromotionCampaign(
      id: 'p1',
      title: '%10',
      type: PromotionType.percentDiscount,
      value: 10,
      minOrderAmount: 100,
    );
    expect(
      PromotionUtils.discountFor(
        campaign: campaign,
        subtotal: 200,
        cartItems: const [],
        productCategories: const {},
      ),
      20,
    );
    expect(
      PromotionUtils.discountFor(
        campaign: campaign,
        subtotal: 50,
        cartItems: const [],
        productCategories: const {},
      ),
      0,
    );
  });

  test('free drinks promotion discounts drink lines', () {
    const campaign = PromotionCampaign(
      id: 'p2',
      title: 'Free drinks',
      type: PromotionType.freeDrinks,
      minOrderAmount: 100,
      autoApply: true,
    );
    const cart = [
      CartItem(
        id: '1',
        productId: 'drink1',
        productNameKey: 'drink',
        unitPrice: 30,
        quantity: 2,
      ),
      CartItem(
        id: '2',
        productId: 'tost1',
        productNameKey: 'tost',
        unitPrice: 80,
        quantity: 1,
      ),
    ];
    final discount = PromotionUtils.discountFor(
      campaign: campaign,
      subtotal: 140,
      cartItems: cart,
      productCategories: const {
        'drink1': ProductCategory.drink,
        'tost1': ProductCategory.tost,
      },
    );
    expect(discount, 60);
  });
}
