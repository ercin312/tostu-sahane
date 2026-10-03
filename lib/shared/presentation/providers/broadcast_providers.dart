import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/app_broadcast.dart';
import 'repository_providers.dart';

final broadcastsProvider = StreamProvider<List<AppBroadcast>>((ref) {
  return ref.watch(broadcastRepositoryProvider).watchBroadcasts();
});

/// Kullanıcının açtığı bildirimler. Rozet, görülmeyenleri sayar.
class SeenBroadcasts extends Notifier<Set<String>> {
  static const _key = 'seen_broadcast_ids_v1';

  @override
  Set<String> build() {
    Future.microtask(_load);
    return {};
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key)?.toSet() ?? {};
  }

  Future<void> markAll(Iterable<String> ids) async {
    final next = {...state, ...ids.where((id) => id.isNotEmpty)};
    if (next.length == state.length) return;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, next.toList());
  }
}

final seenBroadcastsProvider =
    NotifierProvider<SeenBroadcasts, Set<String>>(SeenBroadcasts.new);

int unreadBroadcastCount(List<AppBroadcast> items, Set<String> seen) {
  return items.where((item) => !seen.contains(item.id)).length;
}
