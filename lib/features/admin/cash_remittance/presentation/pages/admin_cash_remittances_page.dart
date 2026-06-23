import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/widgets/cash_remittance_review_page.dart';
import '../../../../../shared/presentation/providers/cash_remittance_providers.dart';
import '../../../presentation/providers/admin_provider.dart';

class AdminCashRemittancesPage extends ConsumerWidget {
  const AdminCashRemittancesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remittancesAsync = ref.watch(adminCashRemittancesProvider);
    final branches = ref.watch(adminBranchesProvider).value ?? [];
    final branchNameById = {for (final b in branches) b.id: b.name};

    return CashRemittanceReviewPage(
      title: LocaleKeys.cashRemittanceAdminTitle.tr(),
      remittancesAsync: remittancesAsync,
      showBranchName: true,
      branchNameById: branchNameById,
    );
  }
}
