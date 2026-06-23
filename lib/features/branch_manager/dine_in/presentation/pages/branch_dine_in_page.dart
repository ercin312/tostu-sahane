import 'package:flutter/material.dart';

import '../../../../branch_manager/dine_in/presentation/pages/dine_in_orders_page.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';

/// Şube paneli — iç siparişler sekmesi.
class BranchDineInPage extends StatelessWidget {
  const BranchDineInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DineInOrdersPage(
      listProvider: branchDineInOrdersProvider,
    );
  }
}
