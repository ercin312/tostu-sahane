import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/features/customer/home/presentation/providers/branch_provider.dart';
import 'package:tostu_sahane/features/customer/orders/presentation/widgets/first_order_empty.dart';
import 'package:tostu_sahane/shared/domain/entities/pickup_settings.dart';
import 'package:tostu_sahane/shared/domain/entities/product.dart';
import 'package:tostu_sahane/shared/domain/entities/promotion_campaign.dart';
import 'package:tostu_sahane/shared/presentation/providers/pickup_settings_provider.dart';
import 'package:tostu_sahane/shared/presentation/providers/promotion_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('empty orders page shows first-order and other campaigns', (
    tester,
  ) async {
    const featured = PromotionCampaign(
      id: 'first',
      title: 'Ilk siparis yuzde 20',
      description: 'Sadece ilk siparis',
      type: PromotionType.percentDiscount,
      value: 20,
      firstOrderOnly: true,
      sortOrder: 0,
    );
    const other = PromotionCampaign(
      id: 'drinks',
      title: 'Icecekler bedava',
      type: PromotionType.freeDrinks,
      sortOrder: 1,
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('tr', 'TR')],
        path: 'unused',
        fallbackLocale: const Locale('tr', 'TR'),
        startLocale: const Locale('tr', 'TR'),
        assetLoader: const _TestAssetLoader(),
        child: ProviderScope(
          overrides: [
            activePromotionCampaignsProvider.overrideWithValue(const [
              featured,
              other,
            ]),
            pickupSettingsProvider.overrideWith(
              (ref) => Stream.value(const PickupSettings()),
            ),
            recommendedProductsProvider.overrideWithValue(const <Product>[]),
          ],
          child: const _Harness(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Henüz siparişin yok'), findsOneWidget);
    expect(find.text('İlk siparişi ver'), findsOneWidget);
    expect(find.text('İlk siparişe özel'), findsWidgets);
    expect(find.text('Diğer kampanyalar'), findsOneWidget);
    expect(find.text('Ilk siparis yuzde 20'), findsOneWidget);
    expect(find.text('Icecekler bedava'), findsOneWidget);
    expect(find.text('%20 · % indirim'), findsOneWidget);
  });
}

class _TestAssetLoader extends AssetLoader {
  const _TestAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return const {
      'orders_empty_title': 'Henüz siparişin yok',
      'orders_empty_hint': 'İlk siparişini ver.',
      'orders_empty_cta': 'İlk siparişi ver',
      'orders_first_campaign': 'İlk siparişe özel',
      'orders_other_campaigns': 'Diğer kampanyalar',
      'admin_promotion_type_percent': '% indirim',
      'admin_promotion_type_free_drinks': 'İçecekler bedava',
    };
  }
}

class _Harness extends StatelessWidget {
  const _Harness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: context.locale,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      home: const Scaffold(body: FirstOrderEmpty()),
    );
  }
}
