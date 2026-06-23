import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../menu/presentation/widgets/admin_product_reviews_panel.dart';

class AdminPendingReviewsPage extends ConsumerWidget {
  const AdminPendingReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.adminPendingReviewsPageTitle.tr()),
      ),
      body: const AdminProductReviewsPanel(showEmptyState: true),
    );
  }
}
