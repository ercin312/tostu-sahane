import 'package:flutter/material.dart';

import '../../../../branch_manager/dine_in/presentation/pages/dine_in_orders_page.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';

/// Sistem yöneticisi — tüm şubelerin bugünkü iç siparişleri.
class AdminDineInPage extends StatelessWidget {
  const AdminDineInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DineInOrdersPage(
      listProvider: dashboardDineInOrdersProvider,
      showBranchName: true,
    );
  }
}
