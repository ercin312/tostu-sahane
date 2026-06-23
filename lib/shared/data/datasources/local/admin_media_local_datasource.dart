import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/media/media_storage_service.dart';
import '../../../domain/entities/media_asset.dart';

class AdminMediaLocalDataSource {
  static const _storageKey = 'admin_media_library_v1';

  static List<MediaAsset> get defaultAssets => [
        MediaAsset(
          id: 'media_default_1',
          source:
              'https://www.tostusahane.com/wp-content/uploads/2026/01/Sucuklu-Kasarli-Tost-1.webp',
          kind: MediaAssetKind.network,
          createdAt: DateTime(2024),
        ),
        MediaAsset(
          id: 'media_default_2',
          source:
              'https://www.tostusahane.com/wp-content/uploads/2026/01/Kavurmali-Kasarli-Tost.webp',
          kind: MediaAssetKind.network,
          createdAt: DateTime(2024),
        ),
        MediaAsset(
          id: 'media_default_3',
          source:
              'https://www.tostusahane.com/wp-content/uploads/2026/01/Ispanakli-Tulumlu-Tost.webp',
          kind: MediaAssetKind.network,
          createdAt: DateTime(2024),
        ),
        MediaAsset(
          id: 'media_default_4',
          source:
              'https://www.tostusahane.com/wp-content/uploads/2026/01/Menemen.webp',
          kind: MediaAssetKind.network,
          createdAt: DateTime(2024),
        ),
        MediaAsset(
          id: 'media_default_5',
          source:
              'https://www.tostusahane.com/wp-content/uploads/2026/01/Patates-Kizartmasi.webp',
          kind: MediaAssetKind.network,
          createdAt: DateTime(2024),
        ),
        MediaAsset(
          id: 'media_default_6',
          source:
              'https://www.tostusahane.com/wp-content/uploads/2026/01/Sahanda-Sucuklu-Yumurta.webp',
          kind: MediaAssetKind.network,
          createdAt: DateTime(2024),
        ),
      ];

  Future<List<MediaAsset>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return List.of(defaultAssets);
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => MediaAsset.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> save(List<MediaAsset> assets) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(assets.map((a) => a.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}

MediaAssetKind kindFromSource(String source) {
  if (MediaStorageService.isNetworkSource(source)) {
    return MediaAssetKind.network;
  }
  if (MediaStorageService.isBase64Source(source)) {
    return MediaAssetKind.local;
  }
  return MediaAssetKind.local;
}
