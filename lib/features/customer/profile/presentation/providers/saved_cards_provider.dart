import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../../shared/data/datasources/local/local_datasources.dart';
import '../../../../../shared/domain/entities/saved_card.dart';

class SavedCardsNotifier extends AsyncNotifier<List<SavedCard>> {
  final _local = SavedCardsLocalDataSource();

  @override
  Future<List<SavedCard>> build() async {
    final auth = ref.watch(authProvider);
    if (auth == null) return [];
    return _local.loadCards(auth.user.id);
  }

  Future<void> addCard({
    required String label,
    required String lastFour,
    required String holderName,
    required String expiry,
    bool setDefault = false,
  }) async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    final current = List<SavedCard>.from(state.value ?? []);
    final id = 'card_${DateTime.now().millisecondsSinceEpoch}';
    final updated = [
      ...current.map((c) => setDefault ? c.copyWith(isDefault: false) : c),
      SavedCard(
        id: id,
        label: label,
        lastFour: lastFour,
        holderName: holderName,
        expiry: expiry,
        isDefault: setDefault || current.isEmpty,
      ),
    ];
    await _local.saveCards(auth.user.id, updated);
    state = AsyncData(updated);
  }

  Future<void> removeCard(String id) async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    var updated = (state.value ?? []).where((c) => c.id != id).toList();
    if (updated.isNotEmpty && !updated.any((c) => c.isDefault)) {
      updated = [
        updated.first.copyWith(isDefault: true),
        ...updated.skip(1),
      ];
    }
    await _local.saveCards(auth.user.id, updated);
    state = AsyncData(updated);
  }

  Future<void> setDefault(String id) async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    final updated = <SavedCard>[
      for (final card in state.value ?? [])
        card.copyWith(isDefault: card.id == id),
    ];
    await _local.saveCards(auth.user.id, updated);
    state = AsyncData(updated);
  }
}

final savedCardsProvider =
    AsyncNotifierProvider<SavedCardsNotifier, List<SavedCard>>(
  SavedCardsNotifier.new,
);
