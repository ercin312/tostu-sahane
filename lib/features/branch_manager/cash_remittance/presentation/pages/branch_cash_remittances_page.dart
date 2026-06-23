import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/widgets/cash_remittance_review_page.dart';
import '../../../../../shared/presentation/providers/cash_remittance_providers.dart';

class BranchCashRemittancesPage extends ConsumerWidget {
  const BranchCashRemittancesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remittancesAsync = ref.watch(branchCashRemittancesProvider);

    return CashRemittanceReviewPage(
      title: LocaleKeys.cashRemittanceBranchTitle.tr(),
      remittancesAsync: remittancesAsync,
    );
  }
}
