import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../../shared/data/datasources/local/local_datasources.dart';

class FavoritesNotifier extends AsyncNotifier<List<String>> {
  final _local = FavoritesLocalDataSource();

  @override
  Future<List<String>> build() async {
    final auth = ref.watch(authProvider);
    if (auth == null) return [];
    return _local.loadFavorites(auth.user.id);
  }

  Future<void> toggle(String productId) async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    final current = List<String>.from(state.value ?? []);
    if (current.contains(productId)) {
      current.remove(productId);
    } else {
      current.add(productId);
    }
    await _local.saveFavorites(auth.user.id, current);
    state = AsyncData(current);
  }

  bool isFavorite(String productId) {
    return (state.value ?? []).contains(productId);
  }
}

final favoritesProvider =
    AsyncNotifierProvider<FavoritesNotifier, List<String>>(
  FavoritesNotifier.new,
);

final isFavoriteProvider = Provider.family<bool, String>((ref, productId) {
  final favorites = ref.watch(favoritesProvider).value ?? [];
  return favorites.contains(productId);
});
