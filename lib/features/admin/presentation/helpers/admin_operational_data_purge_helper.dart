import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/utils/localized_text.dart';
import '../../../../core/widgets/operational_data_purge_dialog.dart';
import '../../../../shared/data/models/api_models.dart';
import '../../../../shared/domain/entities/operational_purge_result.dart';
import '../../../../shared/presentation/providers/operational_data_purge_providers.dart';

bool canPurgeOperationalDataForUser(AdminUserModel user) {
  return user.role == 'courier' ||
      user.role == 'branchManager' ||
      user.role == 'branchStaff';
}

Future<void> purgeOperationalDataForAdminUser({
  required BuildContext context,
  required WidgetRef ref,
  required AdminUserModel user,
}) async {
  final name = localizedOrRaw(user.name);
  final description = switch (user.role) {
    'courier' => LocaleKeys.opsDataPurgeCourierDescription.tr(
        namedArgs: {'name': name},
      ),
    'branchManager' || 'branchStaff' => LocaleKeys.opsDataPurgeBranchDescription
        .tr(namedArgs: {'name': name}),
    _ => '',
  };

  if (description.isEmpty) return;

  if ((user.role == 'branchManager' || user.role == 'branchStaff') &&
      (user.branchId == null || user.branchId!.isEmpty)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocaleKeys.opsDataPurgeNoBranch.tr())),
    );
    return;
  }

  final confirmed = await showOperationalDataPurgeDialog(
    context: context,
    title: LocaleKeys.opsDataPurgeUserAction.tr(),
    description: description,
  );
  if (!confirmed || !context.mounted) return;

  final OperationalPurgeResult result;
  if (user.role == 'courier') {
    result = await purgeCourierOperationalData(ref, user.id);
  } else {
    result = await purgeBranchOperationalData(ref, user.branchId!);
  }

  if (!context.mounted) return;
  showOperationalPurgeSuccessSnackBar(
    context,
    orders: result.ordersDeleted,
    reviews: result.reviewsDeleted,
    remittances: result.remittancesDeleted,
  );
}
