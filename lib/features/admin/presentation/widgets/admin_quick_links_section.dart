import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/presentation/providers/cash_remittance_providers.dart';
import '../../../customer/product_detail/presentation/providers/product_reviews_provider.dart';
import '../config/admin_nav_config.dart';

class AdminQuickLinksSection extends ConsumerWidget {
  const AdminQuickLinksSection({super.key});

  int _badgeCount(WidgetRef ref, AdminNavBadge? badge) {
    return switch (badge) {
      AdminNavBadge.remittances =>
        ref.watch(adminPendingRemittanceCountProvider),
      AdminNavBadge.reviews => ref.watch(adminPendingReviewCountProvider),
      null => 0,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tools = AdminNavConfig.mobileToolsItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.adminToolsTitle.tr(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final item in tools)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Card(
              child: ListTile(
                leading: _leadingIcon(
                  item,
                  _badgeCount(ref, item.badge),
                ),
                title: Text(item.labelKey.tr()),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.go(item.route),
              ),
            ),
          ),
      ],
    );
  }

  Widget _leadingIcon(AdminNavItem item, int count) {
    final icon = Icon(item.filledIcon, color: AppColors.primary);
    if (count <= 0) return icon;
    return Badge(
      isLabelVisible: true,
      label: Text('$count'),
      child: icon,
    );
  }
}
