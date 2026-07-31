import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../../core/config/app_config.dart';
import '../../../../../core/services/geocoding_service.dart';
import '../../../../../shared/data/datasources/local/local_datasources.dart';
import '../../../../../shared/domain/entities/delivery_address.dart';
import '../../../../../shared/presentation/providers/repository_providers.dart';

class AddressNotifier extends AsyncNotifier<List<DeliveryAddress>> {
  final _local = AddressLocalDataSource();
  final _geocoding = const GeocodingService();

  @override
  Future<List<DeliveryAddress>> build() async {
    final auth = ref.watch(authProvider);
    if (auth == null) return [];

    if (AppConfig.useFirestore && !AppConfig.useMockApi) {
      try {
        var remote =
            await ref.read(authRepositoryProvider).getUserAddresses(auth.user.id);
        if (remote.isEmpty) {
          final local = await _local.loadAddresses(auth.user.id);
          if (local.isNotEmpty) {
            await ref
                .read(authRepositoryProvider)
                .saveUserAddresses(auth.user.id, local);
            remote = local;
          }
        }
        return remote;
      } catch (_) {
        return _local.loadAddresses(auth.user.id);
      }
    }

    return _local.loadAddresses(auth.user.id);
  }

  Future<void> _persist(String userId, List<DeliveryAddress> addresses) async {
    await _local.saveAddresses(userId, addresses);
    if (AppConfig.useFirestore && !AppConfig.useMockApi) {
      try {
        await ref
            .read(authRepositoryProvider)
            .saveUserAddresses(userId, addresses);
      } catch (_) {}
    }
  }

  Future<void> addAddress({
    required String title,
    required String fullAddress,
    String? note,
    bool setDefault = false,
    double? latitude,
    double? longitude,
  }) async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    final coords = latitude != null && longitude != null
        ? (latitude, longitude)
        : await _geocoding.resolveAddress(fullAddress).then(
              (c) => c != null ? (c.latitude, c.longitude) : null,
            );
    final current = List<DeliveryAddress>.from(state.value ?? []);
    final id = 'addr_${DateTime.now().millisecondsSinceEpoch}';
    final updated = [
      ...current.map((a) => setDefault ? a.copyWith(isDefault: false) : a),
      DeliveryAddress(
        id: id,
        title: title,
        fullAddress: fullAddress,
        note: note,
        isDefault: setDefault || current.isEmpty,
        latitude: coords?.$1,
        longitude: coords?.$2,
      ),
    ];
    await _persist(auth.user.id, updated);
    state = AsyncData(updated);
  }

  Future<void> updateAddress({
    required String id,
    required String title,
    required String fullAddress,
    String? note,
    double? latitude,
    double? longitude,
  }) async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    final coords = latitude != null && longitude != null
        ? (latitude, longitude)
        : await _geocoding.resolveAddress(fullAddress).then(
              (c) => c != null ? (c.latitude, c.longitude) : null,
            );
    final updated = <DeliveryAddress>[
      for (final address in state.value ?? [])
        if (address.id == id)
          address.copyWith(
            title: title,
            fullAddress: fullAddress,
            note: note,
            latitude: coords?.$1,
            longitude: coords?.$2,
          )
        else
          address,
    ];
    await _persist(auth.user.id, updated);
    state = AsyncData(updated);
  }

  Future<void> removeAddress(String id) async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    var updated = (state.value ?? []).where((a) => a.id != id).toList();
    if (updated.isNotEmpty && !updated.any((a) => a.isDefault)) {
      updated = [
        updated.first.copyWith(isDefault: true),
        ...updated.skip(1),
      ];
    }
    await _persist(auth.user.id, updated);
    state = AsyncData(updated);
  }

  Future<void> setDefault(String id) async {
    final auth = ref.read(authProvider);
    if (auth == null) return;

    final updated = <DeliveryAddress>[
      for (final address in state.value ?? [])
        address.copyWith(isDefault: address.id == id),
    ];
    await _persist(auth.user.id, updated);
    state = AsyncData(updated);
  }
}

final addressProvider =
    AsyncNotifierProvider<AddressNotifier, List<DeliveryAddress>>(
  AddressNotifier.new,
);

final defaultAddressProvider = Provider<DeliveryAddress?>((ref) {
  final addresses = ref.watch(addressProvider).value ?? const [];
  for (final address in addresses) {
    if (address.isDefault) return address;
  }
  return addresses.isEmpty ? null : addresses.first;
});

final selectedCheckoutAddressProvider =
    StateProvider<DeliveryAddress?>((ref) => null);
