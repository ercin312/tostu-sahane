import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/domain/entities/campaign_banner.dart';
import '../../../../shared/presentation/providers/repository_providers.dart';

final campaignBannersProvider = StreamProvider<List<CampaignBanner>>((ref) {
  return ref.watch(adminRepositoryProvider).watchCampaignBanners();
});

/// Müşteri ana sayfasında gösterilecek aktif kampanyalar.
final activeCampaignBannersProvider = Provider<List<CampaignBanner>>((ref) {
  final banners = ref.watch(campaignBannersProvider).value ?? [];
  return banners.where((b) => b.isActive).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});

Future<void> _persistCampaignBanners(
  WidgetRef ref,
  List<CampaignBanner> banners,
) async {
  await ref.read(adminRepositoryProvider).updateCampaignBanners(banners);
}

Future<void> createCampaignBanner(
  WidgetRef ref, {
  String title = '',
  String? imageUrl,
}) async {
  final current = ref.read(campaignBannersProvider).value ?? [];
  final banner = CampaignBanner(
    id: 'camp_${DateTime.now().millisecondsSinceEpoch}',
    title: title,
    imageUrl: imageUrl,
    sortOrder: current.length,
  );
  await _persistCampaignBanners(ref, [...current, banner]);
}

Future<void> updateCampaignBanner(WidgetRef ref, CampaignBanner banner) async {
  final current = ref.read(campaignBannersProvider).value ?? [];
  await _persistCampaignBanners(ref, [
    for (final b in current) if (b.id == banner.id) banner else b,
  ]);
}

Future<void> deleteCampaignBanner(WidgetRef ref, String id) async {
  final current = ref.read(campaignBannersProvider).value ?? [];
  await _persistCampaignBanners(
    ref,
    current.where((b) => b.id != id).toList(),
  );
}

Future<void> toggleCampaignBannerActive(
  WidgetRef ref,
  String id,
  bool active,
) async {
  final current = ref.read(campaignBannersProvider).value ?? [];
  await _persistCampaignBanners(ref, [
    for (final b in current)
      if (b.id == id) b.copyWith(isActive: active) else b,
  ]);
}
