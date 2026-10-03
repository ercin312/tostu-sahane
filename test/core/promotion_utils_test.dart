import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/core/utils/delivery_fee_utils.dart';
import 'package:tostu_sahane/core/utils/promotion_utils.dart';
import 'package:tostu_sahane/shared/domain/entities/branch.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';
import 'package:tostu_sahane/shared/domain/entities/product.dart';
import 'package:tostu_sahane/shared/domain/entities/product_extra.dart';
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

  test('free drinks promotion discounts one drink', () {
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
    expect(discount, 30);
  });

  test('free drinks uses the cart line category when the catalog map is empty', () {
    const campaign = PromotionCampaign(
      id: 'p2b',
      title: 'Free drinks',
      type: PromotionType.freeDrinks,
    );
    const cart = [
      CartItem(
        id: '1',
        productId: 'drink1',
        productNameKey: 'drink',
        unitPrice: 25,
        quantity: 1,
        productCategory: 'drink',
      ),
      CartItem(
        id: '2',
        productId: 'drink2',
        productNameKey: 'drink2',
        unitPrice: 45,
        quantity: 1,
        productCategory: 'drink',
      ),
    ];
    expect(
      PromotionUtils.appliesToCart(
        campaign: campaign,
        cartItems: cart,
        productCategories: const {},
      ),
      isTrue,
    );
    expect(
      PromotionUtils.discountFor(
        campaign: campaign,
        subtotal: 70,
        cartItems: cart,
        productCategories: const {},
      ),
      25,
    );
  });

  test('free drinks discounts one drink extra on a food line', () {
    const campaign = PromotionCampaign(
      id: 'gel-al-drinks',
      title: 'İçecek ücretsiz',
      type: PromotionType.freeDrinks,
      minOrderAmount: 100,
    );
    const cart = [
      CartItem(
        id: '1',
        productId: 'tost1',
        productNameKey: 'tost',
        unitPrice: 210,
        quantity: 1,
        productCategory: 'tost',
        selectedOptions: ['fbt_ayran_30', 'ing_yumurta'],
      ),
    ];
    const extras = {
      'fbt_ayran_30': 40.0,
      'ing_yumurta': 20.0,
    };
    expect(
      PromotionUtils.appliesToCart(
        campaign: campaign,
        cartItems: cart,
        productCategories: const {'tost1': ProductCategory.tost},
        drinkExtraPrices: extras,
      ),
      isTrue,
    );
    expect(
      PromotionUtils.discountFor(
        campaign: campaign,
        subtotal: 210,
        cartItems: cart,
        productCategories: const {'tost1': ProductCategory.tost},
        drinkExtraPrices: {'fbt_ayran_30': 40},
      ),
      40,
    );
    expect(
      PromotionUtils.bestAutoPromotion(
        campaigns: const [campaign],
        subtotal: 210,
        cartItems: cart,
        productCategories: const {'tost1': ProductCategory.tost},
        drinkExtraPrices: const {'fbt_ayran_30': 40},
      )?.id,
      'gel-al-drinks',
    );
  });

  test('drink extra map skips ingredients and food upsells', () {
    const ayran = ProductExtra(id: 'fbt_ayran_30', name: 'extra_ayran', price: 40);
    const egg = ProductExtra(
      id: 'ing_yumurta',
      name: 'Yumurta',
      price: 20,
      kind: ProductExtraKind.ingredient,
    );
    const fries = ProductExtra(
      id: 'ex_patates',
      name: 'product_patates',
      price: 75,
    );
    const products = [
      Product(
        id: 'patates',
        nameKey: 'product_patates',
        descriptionKey: 'd',
        price: 75,
        category: ProductCategory.snack,
      ),
    ];
    expect(
      PromotionUtils.drinkExtraPriceMap(products: products, extras: const [
        ayran,
        egg,
        fries,
      ]),
      {'fbt_ayran_30': 40},
    );
  });

  test('percent promotion respects a maximum discount', () {
    const campaign = PromotionCampaign(
      id: 'cap',
      title: '%50 cap',
      type: PromotionType.percentDiscount,
      value: 50,
      maxDiscount: 30,
    );
    expect(
      PromotionUtils.discountFor(
        campaign: campaign,
        subtotal: 200,
        cartItems: const [],
        productCategories: const {},
      ),
      30,
    );
  });

  test('free item discounts the cheapest matching unit', () {
    const campaign = PromotionCampaign(
      id: 'free',
      title: 'Cheapest toast',
      type: PromotionType.freeItem,
      productIds: ['a', 'b'],
      freeQuantity: 1,
    );
    const cart = [
      CartItem(
        id: '1',
        productId: 'a',
        productNameKey: 'a',
        unitPrice: 80,
        quantity: 1,
      ),
      CartItem(
        id: '2',
        productId: 'b',
        productNameKey: 'b',
        unitPrice: 40,
        quantity: 1,
      ),
    ];
    expect(
      PromotionUtils.discountFor(
        campaign: campaign,
        subtotal: 120,
        cartItems: cart,
        productCategories: const {},
      ),
      40,
    );
  });

  test('buy 2 get 1 frees the cheapest extra unit', () {
    const campaign = PromotionCampaign(
      id: 'bogo',
      title: '2 al 1',
      type: PromotionType.buyXGetY,
      productIds: ['tost'],
      buyQuantity: 2,
      freeQuantity: 1,
    );
    const cart = [
      CartItem(
        id: '1',
        productId: 'tost',
        productNameKey: 'tost',
        unitPrice: 50,
        quantity: 2,
      ),
      CartItem(
        id: '2',
        productId: 'tost',
        productNameKey: 'tost',
        unitPrice: 70,
        quantity: 1,
      ),
    ];
    expect(
      PromotionUtils.discountFor(
        campaign: campaign,
        subtotal: 170,
        cartItems: cart,
        productCategories: const {},
      ),
      50,
    );
  });

  test('first-order campaign applies only for a first order', () {
    const campaign = PromotionCampaign(
      id: 'first',
      title: 'İlk sipariş',
      type: PromotionType.percentDiscount,
      value: 20,
      firstOrderOnly: true,
    );
    expect(
      PromotionUtils.discountFor(
        campaign: campaign,
        subtotal: 100,
        cartItems: const [],
        productCategories: const {},
        isFirstOrder: true,
      ),
      20,
    );
    expect(
      PromotionUtils.discountFor(
        campaign: campaign,
        subtotal: 100,
        cartItems: const [],
        productCategories: const {},
        isFirstOrder: false,
      ),
      0,
    );
    expect(PromotionUtils.canOfferInPicker(campaign, isFirstOrder: false), isFalse);
    expect(PromotionUtils.canOfferInPicker(campaign), isTrue);
  });

  test('campaign products follow product, category, and drink scope', () {
    const drink = Product(
      id: 'd1',
      nameKey: 'ayran',
      descriptionKey: 'ayran',
      price: 20,
      category: ProductCategory.drink,
    );
    const tost = Product(
      id: 't1',
      nameKey: 'kasar',
      descriptionKey: 'kasar',
      price: 80,
      category: ProductCategory.tost,
    );
    const catalog = [drink, tost];

    expect(
      PromotionUtils.productsForCampaign(
        const PromotionCampaign(
          id: 'scoped',
          title: 'Tost',
          type: PromotionType.percentDiscount,
          productIds: ['t1'],
        ),
        catalog,
      ).map((product) => product.id),
      ['t1'],
    );
    expect(
      PromotionUtils.productsForCampaign(
        const PromotionCampaign(
          id: 'drinks',
          title: 'Drinks',
          type: PromotionType.freeDrinks,
        ),
        catalog,
      ).map((product) => product.id),
      ['d1'],
    );
    expect(
      PromotionUtils.productsForCampaign(
        const PromotionCampaign(
          id: 'fee',
          title: 'Fee',
          type: PromotionType.freeDelivery,
        ),
        catalog,
      ),
      isEmpty,
    );
  });

  test('free delivery campaign waives the delivery fee', () {
    const campaign = PromotionCampaign(
      id: 'fee',
      title: 'Free delivery',
      type: PromotionType.freeDelivery,
      minOrderAmount: 100,
    );
    expect(
      PromotionUtils.discountFor(
        campaign: campaign,
        subtotal: 120,
        cartItems: const [],
        productCategories: const {},
        deliveryFee: 35,
      ),
      35,
    );
    expect(
      PromotionUtils.discountFor(
        campaign: campaign,
        subtotal: 40,
        cartItems: const [],
        productCategories: const {},
        deliveryFee: 35,
      ),
      0,
    );
  });
}
