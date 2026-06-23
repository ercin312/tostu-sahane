import '../../../core/localization/locale_keys.dart';
import '../../domain/entities/coupon.dart';
import '../../domain/entities/promotion_campaign.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_extra.dart';
import '../models/api_models.dart';
import '../../domain/entities/product_combo_item.dart';
import '../../domain/entities/branch.dart';

/// tostusahane.com/lezzetler menüsünden alınan örnek ürünler.
abstract final class MockData {
  static const demoOtp = '123456';
  static const demoPassword = 'Sahane123!';
  static const deliveryFee = 0.0;
  static const largePortionExtra = 15.0;

  /// Garson / mutfak demo girişleri (mock ve Firestore ops_users seed).
  static const demoOpsUsers = [
    AdminUserModel(
      id: 'w1',
      name: 'Garson Ali',
      role: 'waiter',
      phone: '',
      username: 'garson1',
      password: demoPassword,
      isActive: true,
      branchId: 'branch_1',
    ),
    AdminUserModel(
      id: 'k1',
      name: 'Mutfak',
      role: 'kitchenStaff',
      phone: '',
      username: 'mutfak1',
      password: demoPassword,
      isActive: true,
      branchId: 'branch_1',
    ),
  ];

  static const branches = [
    Branch(
      id: 'branch_1',
      name: 'Tost-u Şahane Merkez',
      address: 'Cumhuriyet Mh. Muhammed Müftüoğlu Cd.',
      latitude: 36.5444,
      longitude: 31.9958,
      distanceKm: 0.8,
      deliveryRadiusKm: 5.0,
    ),
    Branch(
      id: 'branch_2',
      name: 'Tost-u Şahane Şube',
      address: 'Cumhuriyet Mh. Muhammed Müftüoğlu Cd.',
      latitude: 36.5480,
      longitude: 31.9900,
      distanceKm: 1.2,
      deliveryRadiusKm: 4.0,
    ),
  ];

  static const catalogExtras = [
    ProductExtra(
      id: 'fbt_coca_cola_33',
      name: 'extra_coca_cola_33_name',
      price: 90,
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/9/9d/Coca-Cola_can.jpg/320px-Coca-Cola_can.jpg',
    ),
    ProductExtra(
      id: 'fbt_ayran_30',
      name: 'extra_ayran_30_name',
      price: 50,
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/8/8a/Ayran.jpg/320px-Ayran.jpg',
    ),
    ProductExtra(
      id: 'fbt_karisik_tost',
      name: 'product_karisik_tost_name',
      price: 240,
      imageUrl:
          'https://www.tostusahane.com/wp-content/uploads/2026/01/Karisik-Tost.webp',
    ),
    ProductExtra(
      id: 'fbt_ice_tea_peach',
      name: 'extra_ice_tea_peach_name',
      price: 90,
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/e/e8/Ice_tea_with_lemon.jpg/320px-Ice_tea_with_lemon.jpg',
    ),
    ProductExtra(
      id: 'fbt_coca_cola_1l',
      name: 'extra_coca_cola_1l_name',
      price: 120,
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5b/Coca-Cola_bottle.jpg/320px-Coca-Cola_bottle.jpg',
    ),
    ProductExtra(
      id: 'fbt_soda_20',
      name: 'extra_soda_20_name',
      price: 50,
      imageUrl:
          'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4f/Beypazari_Soda.jpg/320px-Beypazari_Soda.jpg',
    ),
    ProductExtra(
      id: 'ex_patates',
      name: 'product_patates_kizartmasi_name',
      price: 75,
      imageUrl:
          'https://www.tostusahane.com/wp-content/uploads/2026/01/Patates-Kizartmasi.webp',
    ),
  ];

  static const defaultProductExtraIds = [
    'fbt_coca_cola_33',
    'fbt_ayran_30',
    'fbt_karisik_tost',
    'fbt_ice_tea_peach',
    'fbt_coca_cola_1l',
    'fbt_soda_20',
  ];

  static const tostProductExtraIds = [
    ...defaultProductExtraIds,
    'ex_patates',
  ];

  static const products = [
    Product(
      id: 'ts_menemen',
      nameKey: 'product_menemen_name',
      descriptionKey: 'product_menemen_desc',
      price: 140.00,
      category: ProductCategory.sahanda,
      imageColorValue: 0xFFFFF3E0,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Menemen.webp',
      extraIds: defaultProductExtraIds,
      isRecommended: true,
    ),
    Product(
      id: 'ts_sahanda_kavurmali_yumurta',
      nameKey: 'product_sahanda_kavurmali_yumurta_name',
      descriptionKey: 'product_sahanda_kavurmali_yumurta_desc',
      price: 200.00,
      category: ProductCategory.sahanda,
      imageColorValue: 0xFFFFF3E0,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Sahanda-Kavurmali-Yumurta.webp',
      extraIds: defaultProductExtraIds,
      isRecommended: true,
    ),
    Product(
      id: 'ts_sahanda_sucuklu_yumurta',
      nameKey: 'product_sahanda_sucuklu_yumurta_name',
      descriptionKey: 'product_sahanda_sucuklu_yumurta_desc',
      price: 160.00,
      category: ProductCategory.sahanda,
      imageColorValue: 0xFFFFF3E0,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Sahanda-Sucuklu-Yumurta.webp',
      extraIds: defaultProductExtraIds,
    ),
    Product(
      id: 'ts_sahanda_yumurta',
      nameKey: 'product_sahanda_yumurta_name',
      descriptionKey: 'product_sahanda_yumurta_desc',
      price: 120.00,
      category: ProductCategory.sahanda,
      imageColorValue: 0xFFFFF3E0,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Sahanda-Yumurta.webp',
      extraIds: defaultProductExtraIds,
    ),
    Product(
      id: 'ts_patates_kizartmasi',
      nameKey: 'product_patates_kizartmasi_name',
      descriptionKey: 'product_patates_kizartmasi_desc',
      price: 75.00,
      category: ProductCategory.snack,
      imageColorValue: 0xFFFFF8E1,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Patates-Kizartmasi.webp',
      extraIds: defaultProductExtraIds,
    ),
    Product(
      id: 'ts_akdeniz_tost',
      nameKey: 'product_akdeniz_tost_name',
      descriptionKey: 'product_akdeniz_tost_desc',
      price: 115.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Akdeniz-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_bazlama_tost',
      nameKey: 'product_bazlama_tost_name',
      descriptionKey: 'product_bazlama_tost_desc',
      price: 150.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Bazlama-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_beyaz_peynir_kasarli_tost',
      nameKey: 'product_beyaz_peynir_kasarli_tost_name',
      descriptionKey: 'product_beyaz_peynir_kasarli_tost_desc',
      price: 95.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Beyaz-Peynir-Kasarli-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_beyaz_peynirli_tost',
      nameKey: 'product_beyaz_peynirli_tost_name',
      descriptionKey: 'product_beyaz_peynirli_tost_desc',
      price: 90.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Beyaz-Peynirli-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_ispanak_tulum_yumurtali_tost',
      nameKey: 'product_ispanak_tulum_yumurtali_tost_name',
      descriptionKey: 'product_ispanak_tulum_yumurtali_tost_desc',
      price: 120.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Ispanak-Tulum-Yumurtali-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_ispanakli_kasarli_tost',
      nameKey: 'product_ispanakli_kasarli_tost_name',
      descriptionKey: 'product_ispanakli_kasarli_tost_desc',
      price: 110.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Ispanakli-Kasarli-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_ispanakli_tulumlu_tost',
      nameKey: 'product_ispanakli_tulumlu_tost_name',
      descriptionKey: 'product_ispanakli_tulumlu_tost_desc',
      price: 100.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Ispanakli-Tulumlu-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_ispanakli_yumurtali_tost',
      nameKey: 'product_ispanakli_yumurtali_tost_name',
      descriptionKey: 'product_ispanakli_yumurtali_tost_desc',
      price: 120.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Ispanakli-Yumurtali-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_karisik_sebzeli_tost',
      nameKey: 'product_karisik_sebzeli_tost_name',
      descriptionKey: 'product_karisik_sebzeli_tost_desc',
      price: 140.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Karisik-Sebzeli-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_karisik_tost',
      nameKey: 'product_karisik_tost_name',
      descriptionKey: 'product_karisik_tost_desc',
      price: 140.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Karisik-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_kasarli_sebzeli_tost',
      nameKey: 'product_kasarli_sebzeli_tost_name',
      descriptionKey: 'product_kasarli_sebzeli_tost_desc',
      price: 95.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Kasarli-Sebzeli-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_kasarli_tost',
      nameKey: 'product_kasarli_tost_name',
      descriptionKey: 'product_kasarli_tost_desc',
      price: 95.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Kasarli-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_kavurmali_kasarli_tost',
      nameKey: 'product_kavurmali_kasarli_tost_name',
      descriptionKey: 'product_kavurmali_kasarli_tost_desc',
      price: 210.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Kavurmali-Kasarli-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_kavurmali_yumurtali_tost',
      nameKey: 'product_kavurmali_yumurtali_tost_name',
      descriptionKey: 'product_kavurmali_yumurtali_tost_desc',
      price: 210.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Kavurmali-Yumurtali-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_pastirmali_kasarli_tost',
      nameKey: 'product_pastirmali_kasarli_tost_name',
      descriptionKey: 'product_pastirmali_kasarli_tost_desc',
      price: 190.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Pastirmali-Kasarli-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_pastirmali_yumurtali_tost',
      nameKey: 'product_pastirmali_yumurtali_tost_name',
      descriptionKey: 'product_pastirmali_yumurtali_tost_desc',
      price: 190.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Pastirmali-Yumurtali-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_protein_bombasi',
      nameKey: 'product_protein_bombasi_name',
      descriptionKey: 'product_protein_bombasi_desc',
      price: 180.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Protein-Bombasi.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_sucuklu_kasarli_tost',
      nameKey: 'product_sucuklu_kasarli_tost_name',
      descriptionKey: 'product_sucuklu_kasarli_tost_desc',
      price: 130.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Sucuklu-Kasarli-Tost-1.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_sucuklu_sebzeli_tost',
      nameKey: 'product_sucuklu_sebzeli_tost_name',
      descriptionKey: 'product_sucuklu_sebzeli_tost_desc',
      price: 130.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Sucuklu-Sebzeli-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_sucuklu_yumurtali_tost',
      nameKey: 'product_sucuklu_yumurtali_tost_name',
      descriptionKey: 'product_sucuklu_yumurtali_tost_desc',
      price: 150.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Sucuklu-Yumurtali-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_yumurta_kasarli_tost',
      nameKey: 'product_yumurta_kasarli_tost_name',
      descriptionKey: 'product_yumurta_kasarli_tost_desc',
      price: 120.00,
      category: ProductCategory.tost,
      imageColorValue: 0xFFFFE0E6,
      imageUrl: 'https://www.tostusahane.com/wp-content/uploads/2026/01/Yumurta-Kasarli-Tost.webp',
      extraIds: tostProductExtraIds,
    ),
    Product(
      id: 'ts_ayran',
      nameKey: 'product_ayran_name',
      descriptionKey: 'product_ayran_desc',
      price: 35.00,
      category: ProductCategory.drink,
      imageColorValue: 0xFFE3F2FD,
      extraIds: defaultProductExtraIds,
    ),
    Product(
      id: 'combo_tost_ayran',
      nameKey: 'product_combo_tost_ayran_name',
      descriptionKey: 'product_combo_tost_ayran_desc',
      price: 135.00,
      category: ProductCategory.combo,
      imageColorValue: 0xFFFFE0E6,
      extraIds: defaultProductExtraIds,
      isCombo: true,
      comboItems: const [
        ProductComboItem(
          productId: 'ts_akdeniz_tost',
          nameKey: 'product_akdeniz_tost_name',
        ),
        ProductComboItem(
          productId: 'ts_ayran',
          nameKey: 'product_ayran_name',
        ),
      ],
    ),
    Product(
      id: 'combo_menemen_cay',
      nameKey: 'product_combo_menemen_cay_name',
      descriptionKey: 'product_combo_menemen_cay_desc',
      price: 165.00,
      category: ProductCategory.combo,
      imageColorValue: 0xFFFFF3E0,
      extraIds: defaultProductExtraIds,
      isCombo: true,
      comboItems: const [
        ProductComboItem(
          productId: 'ts_menemen',
          nameKey: 'product_menemen_name',
        ),
        ProductComboItem(
          productId: 'ts_cay',
          nameKey: 'product_cay_name',
        ),
      ],
    ),
    Product(
      id: 'ts_cay',
      nameKey: 'product_cay_name',
      descriptionKey: 'product_cay_desc',
      price: 25.00,
      category: ProductCategory.drink,
      imageColorValue: 0xFFFFF8E1,
      extraIds: defaultProductExtraIds,
    ),
  ];

  static const campaignKeys = [
    LocaleKeys.campaignTitle1,
    LocaleKeys.campaignTitle2,
    LocaleKeys.campaignTitle3,
  ];

  static const categoryKeys = {
    ProductCategory.all: LocaleKeys.customerCategoriesAll,
    ProductCategory.tost: LocaleKeys.customerCategoryTost,
    ProductCategory.sahanda: LocaleKeys.customerCategorySahanda,
    ProductCategory.drink: LocaleKeys.customerCategoryDrink,
    ProductCategory.snack: LocaleKeys.customerCategorySnack,
    ProductCategory.combo: LocaleKeys.customerCategoryCombo,
  };

  static const couriers = [
    ('courier_1', 'Ahmet Kurye'),
    ('courier_2', 'Mehmet Kurye'),
  ];

  static const coupons = [
    Coupon(
      code: 'SAHANE10',
      type: CouponType.percent,
      value: 10,
      minOrderAmount: 50,
    ),
    Coupon(
      code: 'TOS20',
      type: CouponType.fixed,
      value: 20,
      minOrderAmount: 100,
    ),
  ];

  static const promotions = [
    PromotionCampaign(
      id: 'promo_free_drinks',
      title: '200 TL üzeri içecekler ücretsiz',
      type: PromotionType.freeDrinks,
      minOrderAmount: 200,
      autoApply: true,
      sortOrder: 0,
    ),
    PromotionCampaign(
      id: 'promo_percent_15',
      title: '%15 indirim',
      type: PromotionType.percentDiscount,
      code: 'INDIRIM15',
      value: 15,
      minOrderAmount: 150,
      sortOrder: 1,
    ),
  ];

  static const defaultAddress = 'Cumhuriyet Mh. Muhammed Müftüoğlu Cd.';

  static String? imageUrlForProduct(String productId) {
    for (final product in products) {
      if (product.id == productId) return product.imageUrl;
    }
    return null;
  }

  static String? imageUrlForExtra(String extraId) {
    for (final extra in catalogExtras) {
      if (extra.id == extraId) return extra.imageUrl;
    }
    return null;
  }
}
