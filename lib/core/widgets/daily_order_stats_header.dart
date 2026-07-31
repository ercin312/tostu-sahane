import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../localization/locale_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';

/// Sipariş sayfası üstü: bugünün cirosu + sipariş adedi (TR günü).
class DailyOrderStatsHeader extends StatelessWidget {
  const DailyOrderStatsHeader({
    super.key,
    required this.revenue,
    required this.orderCount,
  });

  final double revenue;
  final int orderCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _DailyStatCard(
              title: LocaleKeys.branchDailyRevenue.tr(),
              value: FormatUtils.currency(revenue),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _DailyStatCard(
              title: LocaleKeys.branchOrderCount.tr(),
              value: '$orderCount',
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyStatCard extends StatelessWidget {
  const _DailyStatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
