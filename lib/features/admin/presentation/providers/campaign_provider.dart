import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/data/datasources/local/campaign_local_datasource.dart';
import '../../../../shared/domain/entities/campaign_banner.dart';

class CampaignBannersNotifier extends AsyncNotifier<List<CampaignBanner>> {
  final _local = CampaignLocalDataSource();

  @override
  Future<List<CampaignBanner>> build() => _local.load();

  Future<void> _persist(List<CampaignBanner> banners) async {
    await _local.save(banners);
    state = AsyncData(banners);
  }

  Future<void> createBanner({
    String title = '',
    String? imageUrl,
  }) async {
    final current = state.value ?? [];
    final banner = CampaignBanner(
      id: 'camp_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      imageUrl: imageUrl,
      sortOrder: current.length,
    );
    await _persist([...current, banner]);
  }

  Future<void> updateBanner(CampaignBanner banner) async {
    final current = state.value ?? [];
    await _persist([
      for (final b in current) if (b.id == banner.id) banner else b,
    ]);
  }

  Future<void> deleteBanner(String id) async {
    final current = state.value ?? [];
    await _persist(current.where((b) => b.id != id).toList());
  }

  Future<void> toggleActive(String id, bool active) async {
    final current = state.value ?? [];
    await _persist([
      for (final b in current)
        if (b.id == id) b.copyWith(isActive: active) else b,
    ]);
  }
}

final campaignBannersProvider =
    AsyncNotifierProvider<CampaignBannersNotifier, List<CampaignBanner>>(
  CampaignBannersNotifier.new,
);

/// Müşteri ana sayfasında gösterilecek aktif kampanyalar.
final activeCampaignBannersProvider = Provider<List<CampaignBanner>>((ref) {
  final banners = ref.watch(campaignBannersProvider).value ?? [];
  return banners.where((b) => b.isActive).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
});
