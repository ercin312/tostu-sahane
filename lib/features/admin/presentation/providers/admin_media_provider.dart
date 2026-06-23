import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/media/media_storage_service.dart';
import '../../../../shared/data/datasources/local/admin_media_local_datasource.dart';
import '../../../../shared/domain/entities/media_asset.dart';

class AdminMediaNotifier extends AsyncNotifier<List<MediaAsset>> {
  final _local = AdminMediaLocalDataSource();

  @override
  Future<List<MediaAsset>> build() => _local.load();

  Future<void> _persist(List<MediaAsset> assets) async {
    final sorted = [...assets]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _local.save(sorted);
    state = AsyncData(sorted);
  }

  Future<void> addFromPicker() async {
    final path = await MediaStorageService.pickAndSaveImage();
    if (path == null) return;
    await addSource(path);
  }

  Future<void> addUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;
    await addSource(trimmed);
  }

  Future<void> addSource(String source) async {
    final asset = MediaAsset(
      id: 'media_${DateTime.now().millisecondsSinceEpoch}',
      source: source,
      kind: kindFromSource(source),
      createdAt: DateTime.now(),
    );
    final current = state.value ?? [];
    await _persist([asset, ...current]);
  }

  Future<void> remove(String id) async {
    final current = state.value ?? [];
    final target = current.where((a) => a.id == id).firstOrNull;
    if (target != null && target.kind == MediaAssetKind.local) {
      await MediaStorageService.deleteIfLocal(target.source);
    }
    await _persist(current.where((a) => a.id != id).toList());
  }
}

final adminMediaProvider =
    AsyncNotifierProvider<AdminMediaNotifier, List<MediaAsset>>(
  AdminMediaNotifier.new,
);

/// Hazır görsel kaynakları (en yeni önce).
final adminMediaSourcesProvider = Provider<List<String>>((ref) {
  final assets = ref.watch(adminMediaProvider).value ?? [];
  return assets.map((a) => a.source).toList();
});
