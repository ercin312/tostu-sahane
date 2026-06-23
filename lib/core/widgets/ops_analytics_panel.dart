import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../analytics/ops_analytics.dart';
import '../localization/locale_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class OpsAnalyticsPanel extends StatelessWidget {
  const OpsAnalyticsPanel({super.key, required this.analytics});

  final OpsAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.opsAnalyticsTitle.tr(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          LocaleKeys.opsStaffTitle.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (analytics.staffStats.isEmpty)
          Text(
            LocaleKeys.opsNoData.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          )
        else
          ...analytics.staffStats.map(
            (s) => _StatTile(
              title: s.userName,
              subtitle: LocaleKeys.opsStaffOrders.tr(
                namedArgs: {'count': '${s.orderCount}'},
              ),
              icon: Icons.person_outline,
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          LocaleKeys.opsCourierTitle.tr(),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (analytics.courierStats.isEmpty)
          Text(
            LocaleKeys.opsNoData.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          )
        else
          ...analytics.courierStats.map(
            (c) => _StatTile(
              title: c.courierName,
              subtitle: LocaleKeys.opsCourierSummary.tr(
                namedArgs: {
                  'count': '${c.todayDeliveries}',
                  'avg': '${c.avgDeliveryMinutes}',
                  'min': '${c.minDeliveryMinutes}',
                  'max': '${c.maxDeliveryMinutes}',
                },
              ),
              icon: Icons.delivery_dining,
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
