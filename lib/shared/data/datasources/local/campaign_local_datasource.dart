import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../domain/entities/campaign_banner.dart';

class CampaignLocalDataSource {
  static const _storageKey = 'campaign_banners_v1';

  static List<CampaignBanner> get defaults => [
        CampaignBanner(
          id: 'camp_1',
          title: LocaleKeys.campaignTitle1,
          imageUrl:
              'https://www.tostusahane.com/wp-content/uploads/2026/01/Kavurmali-Kasarli-Tost.webp',
          sortOrder: 0,
          actionUrl: '/customer/cart',
          actionLabel: LocaleKeys.customerCampaigns,
        ),
        CampaignBanner(
          id: 'camp_2',
          title: LocaleKeys.campaignTitle2,
          imageUrl:
              'https://www.tostusahane.com/wp-content/uploads/2026/01/Ispanakli-Tulumlu-Tost.webp',
          sortOrder: 1,
        ),
        CampaignBanner(
          id: 'camp_3',
          title: LocaleKeys.campaignTitle3,
          imageUrl:
              'https://www.tostusahane.com/wp-content/uploads/2026/01/Sucuklu-Kasarli-Tost-1.webp',
          sortOrder: 2,
        ),
      ];

  Future<List<CampaignBanner>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return List.of(defaults);
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CampaignBanner.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  Future<void> save(List<CampaignBanner> banners) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(banners.map((b) => b.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
