import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/domain/entities/qr_menu_settings.dart';
import '../../../../../shared/domain/entities/user.dart';
import '../../../../../shared/presentation/providers/repository_providers.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../customer/home/presentation/providers/branch_provider.dart';

final qrMenuSettingsProvider =
    AsyncNotifierProvider<QrMenuSettingsNotifier, QrMenuSettings>(
  QrMenuSettingsNotifier.new,
);

class QrMenuSettingsNotifier extends AsyncNotifier<QrMenuSettings> {
  @override
  Future<QrMenuSettings> build() {
    return ref.read(adminRepositoryProvider).getQrMenuSettings();
  }

  Future<void> save(QrMenuSettings settings) async {
    final saved =
        await ref.read(adminRepositoryProvider).updateQrMenuSettings(settings);
    state = AsyncData(saved);
  }
}

final pendingTableServiceRequestsProvider =
    StreamProvider<List<TableServiceRequest>>((ref) {
  final auth = ref.watch(authProvider);
  if (auth == null) return Stream.value(const []);
  final role = auth.user.role;
  final listen = role == UserRole.waiter ||
      role == UserRole.branchManager ||
      role == UserRole.branchStaff ||
      role == UserRole.superAdmin ||
      role == UserRole.kitchenStaff;
  if (!listen) return Stream.value(const []);

  String? branchId = auth.user.branchId;
  if (role == UserRole.superAdmin) {
    branchId = ref.watch(managedBranchProvider).value?.id ?? branchId;
  } else {
    branchId ??= ref.watch(managedBranchProvider).value?.id;
  }

  return ref
      .read(adminRepositoryProvider)
      .watchPendingTableServiceRequests(branchId: branchId);
});
