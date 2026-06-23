import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../shared/domain/entities/order.dart';
import '../analytics/admin_reports_analytics.dart';
import '../analytics/ops_analytics.dart';
import '../localization/locale_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/format_utils.dart';
import '../utils/localized_text.dart';
import '../utils/order_status_utils.dart';
import '../utils/payment_method_utils.dart';

class AdminReportsDashboard extends StatelessWidget {
  const AdminReportsDashboard({
    super.key,
    required this.snapshot,
    required this.period,
    required this.onPeriodChanged,
    required this.customRange,
    required this.onCustomRangeChanged,
    required this.branches,
    this.selectedBranchId,
    required this.onBranchChanged,
    this.activeBranches = 0,
  });

  final AdminReportSnapshot snapshot;
  final AdminReportPeriod period;
  final ValueChanged<AdminReportPeriod> onPeriodChanged;
  final AdminReportDateRange customRange;
  final ValueChanged<AdminReportDateRange> onCustomRangeChanged;
  final List<({String id, String name})> branches;
  final String? selectedBranchId;
  final ValueChanged<String?> onBranchChanged;
  final int activeBranches;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportsHero(
          snapshot: snapshot,
          period: period,
          activeBranches: activeBranches,
        ),
        Transform.translate(
          offset: const Offset(0, -28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                _PeriodSelector(
                  period: period,
                  customRange: customRange,
                  onChanged: onPeriodChanged,
                  onCustomRangeChanged: onCustomRangeChanged,
                ),
                const SizedBox(height: AppSpacing.sm),
                _BranchFilterBar(
                  branches: branches,
                  selectedBranchId: selectedBranchId,
                  onChanged: onBranchChanged,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: -8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _KpiGrid(snapshot: snapshot),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _SectionCard(
            icon: Icons.show_chart_rounded,
            title: LocaleKeys.adminReportsRevenueTrend.tr(),
            child: _RevenueBarChart(points: snapshot.revenueTrend),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 900;
              final statusCard = _SectionCard(
                icon: Icons.pie_chart_outline_rounded,
                title: LocaleKeys.adminReportsStatusBreakdown.tr(),
                child: _StatusBreakdownList(slices: snapshot.statusBreakdown),
              );
              final paymentCard = _SectionCard(
                icon: Icons.payments_outlined,
                title: LocaleKeys.adminReportsPaymentBreakdown.tr(),
                child:
                    _PaymentBreakdownList(slices: snapshot.paymentBreakdown),
              );
              if (sideBySide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: statusCard),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: paymentCard),
                  ],
                );
              }
              return Column(
                children: [
                  statusCard,
                  const SizedBox(height: AppSpacing.md),
                  paymentCard,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _SectionCard(
            icon: Icons.schedule_rounded,
            title: LocaleKeys.adminReportsPeakHours.tr(),
            child: _PeakHoursChart(buckets: snapshot.peakHours),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (selectedBranchId == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: _SectionCard(
              icon: Icons.storefront_outlined,
              title: LocaleKeys.adminReportsBranchRanking.tr(),
              child: _BranchRankingList(rankings: snapshot.branchRankings),
            ),
          ),
        if (selectedBranchId == null) const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _SectionCard(
            icon: Icons.local_fire_department_outlined,
            title: LocaleKeys.adminReportsTopProducts.tr(),
            child: _TopProductsList(products: snapshot.topProducts.take(8)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: _SectionCard(
            icon: Icons.groups_outlined,
            title: LocaleKeys.opsAnalyticsTitle.tr(),
            child: _TeamPerformanceSection(
              analytics: snapshot.opsAnalytics,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _BranchFilterBar extends StatelessWidget {
  const _BranchFilterBar({
    required this.branches,
    required this.selectedBranchId,
    required this.onChanged,
  });

  final List<({String id, String name})> branches;
  final String? selectedBranchId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.filter_list_rounded,
                size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: selectedBranchId,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(LocaleKeys.adminReportsBranchFilterAll.tr()),
                    ),
                    ...branches.map(
                      (branch) => DropdownMenuItem<String?>(
                        value: branch.id,
                        child: Text(branch.name),
                      ),
                    ),
                  ],
                  onChanged: onChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportsHero extends StatelessWidget {
  const _ReportsHero({
    required this.snapshot,
    required this.period,
    required this.activeBranches,
  });

  final AdminReportSnapshot snapshot;
  final AdminReportPeriod period;
  final int activeBranches;

  String _periodLabel(BuildContext context) {
    if (period == AdminReportPeriod.custom) {
      final locale = context.locale.toString();
      final start =
          DateFormat('d MMM yyyy', locale).format(snapshot.rangeStart);
      final end = DateFormat('d MMM yyyy', locale).format(snapshot.rangeEnd);
      return LocaleKeys.adminReportsDateRangeValue.tr(
        namedArgs: {'start': start, 'end': end},
      );
    }
    return switch (period) {
      AdminReportPeriod.today => LocaleKeys.adminReportsPeriodToday.tr(),
      AdminReportPeriod.last7Days => LocaleKeys.adminReportsPeriodWeek.tr(),
      AdminReportPeriod.last30Days => LocaleKeys.adminReportsPeriodMonth.tr(),
      AdminReportPeriod.custom => LocaleKeys.adminReportsPeriodCustom.tr(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.xl + 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LocaleKeys.adminReportsOverview.tr(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.6,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _periodLabel(context),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  label: LocaleKeys.adminTotalRevenue.tr(),
                  value: FormatUtils.currency(snapshot.totalRevenue),
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: AppColors.white.withValues(alpha: 0.25),
              ),
              Expanded(
                child: _HeroMetric(
                  label: LocaleKeys.adminTotalOrders.tr(),
                  value: '${snapshot.orderCount}',
                ),
              ),
              Container(
                width: 1,
                height: 44,
                color: AppColors.white.withValues(alpha: 0.25),
              ),
              Expanded(
                child: _HeroMetric(
                  label: LocaleKeys.adminActiveBranches.tr(),
                  value: '$activeBranches',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(
                icon: Icons.check_circle_outline,
                label: LocaleKeys.adminReportsDelivered.tr(
                  namedArgs: {'count': '${snapshot.deliveredCount}'},
                ),
              ),
              _HeroChip(
                icon: Icons.timelapse_rounded,
                label: LocaleKeys.adminReportsActiveNow.tr(
                  namedArgs: {'count': '${snapshot.activeCount}'},
                ),
              ),
              if (snapshot.cancelledCount > 0)
                _HeroChip(
                  icon: Icons.cancel_outlined,
                  label: LocaleKeys.adminReportsCancelled.tr(
                    namedArgs: {'count': '${snapshot.cancelledCount}'},
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.8),
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.period,
    required this.customRange,
    required this.onChanged,
    required this.onCustomRangeChanged,
  });

  final AdminReportPeriod period;
  final AdminReportDateRange customRange;
  final ValueChanged<AdminReportPeriod> onChanged;
  final ValueChanged<AdminReportDateRange> onCustomRangeChanged;

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: customRange.start,
        end: customRange.end,
      ),
      helpText: LocaleKeys.adminReportsSelectDateRange.tr(),
      saveText: LocaleKeys.commonOk.tr(),
      cancelText: LocaleKeys.commonCancel.tr(),
    );
    if (picked == null || !context.mounted) return;

    onCustomRangeChanged(
      AdminReportDateRange(
        start: AdminReportDateRange.dayStart(picked.start),
        end: AdminReportDateRange.dayStart(picked.end),
      ).normalized(),
    );
    onChanged(AdminReportPeriod.custom);
  }

  String _formatRange(BuildContext context) {
    final locale = context.locale.toString();
    final start = DateFormat('d MMM yyyy', locale).format(customRange.start);
    final end = DateFormat('d MMM yyyy', locale).format(customRange.end);
    return LocaleKeys.adminReportsDateRangeValue.tr(
      namedArgs: {'start': start, 'end': end},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(16),
      color: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: AdminReportPeriod.values.map((value) {
                final selected = value == period;
                final label = switch (value) {
                  AdminReportPeriod.today =>
                    LocaleKeys.adminReportsPeriodToday.tr(),
                  AdminReportPeriod.last7Days =>
                    LocaleKeys.adminReportsPeriodWeek.tr(),
                  AdminReportPeriod.last30Days =>
                    LocaleKeys.adminReportsPeriodMonth.tr(),
                  AdminReportPeriod.custom =>
                    LocaleKeys.adminReportsPeriodCustom.tr(),
                };
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (value == AdminReportPeriod.custom) {
                          _pickCustomRange(context);
                        } else {
                          onChanged(value);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: selected
                                        ? AppColors.white
                                        : AppColors.textSecondary,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            if (period == AdminReportPeriod.custom) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => _pickCustomRange(context),
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(
                  _formatRange(context),
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.35),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.snapshot});

  final AdminReportSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiData(
        icon: Icons.shopping_bag_outlined,
        label: LocaleKeys.adminReportsAvgBasket.tr(),
        value: FormatUtils.currency(snapshot.avgOrderValue),
        color: AppColors.warning,
      ),
      _KpiData(
        icon: Icons.block_flipped,
        label: LocaleKeys.adminReportsCancelRate.tr(),
        value: '${snapshot.cancellationRate.toStringAsFixed(1)}%',
        color: snapshot.cancellationRate > 10
            ? AppColors.error
            : AppColors.success,
      ),
      _KpiData(
        icon: Icons.delivery_dining_outlined,
        label: LocaleKeys.adminReportsAvgDelivery.tr(),
        value: snapshot.avgDeliveryMinutes != null
            ? LocaleKeys.orderAuditMinutes.tr(
                namedArgs: {'minutes': '${snapshot.avgDeliveryMinutes}'},
              )
            : '—',
        color: const Color(0xFF5C6BC0),
      ),
      _KpiData(
        icon: Icons.timer_outlined,
        label: LocaleKeys.adminReportsAvgFulfillment.tr(),
        value: snapshot.avgFulfillmentMinutes != null
            ? LocaleKeys.orderAuditMinutes.tr(
                namedArgs: {'minutes': '${snapshot.avgFulfillmentMinutes}'},
              )
            : '—',
        color: const Color(0xFF00897B),
      ),
      _KpiData(
        icon: Icons.star_rounded,
        label: LocaleKeys.adminReportsAvgRating.tr(),
        value: snapshot.avgRating != null
            ? '${snapshot.avgRating!.toStringAsFixed(1)} ★'
            : '—',
        color: const Color(0xFFFFB300),
      ),
      _KpiData(
        icon: Icons.rate_review_outlined,
        label: LocaleKeys.adminReportsRatedOrders.tr(),
        value: '${snapshot.ratedOrderCount}',
        color: AppColors.primary,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 720 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: crossAxisCount == 3 ? 1.55 : 1.35,
          ),
          itemBuilder: (context, index) => _KpiCard(data: items[index]),
        );
      },
    );
  }
}

class _KpiData {
  const _KpiData({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.data});

  final _KpiData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: data.color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const Spacer(),
          Text(
            data.value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  const _RevenueBarChart({required this.points});

  final List<DailyRevenuePoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty || points.every((p) => p.revenue == 0)) {
      return _EmptyHint(message: LocaleKeys.adminReportsNoOrdersInPeriod.tr());
    }

    final maxRevenue = points
        .map((p) => p.revenue)
        .fold<double>(0, math.max)
        .clamp(1, double.infinity);

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in points) ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (point.orderCount > 0)
                      Text(
                        '${point.orderCount}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    const SizedBox(height: 4),
                    Flexible(
                      child: FractionallySizedBox(
                        heightFactor: (point.revenue / maxRevenue).clamp(0.08, 1),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0.55),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat(
                        points.length <= 7 ? 'E' : 'd/M',
                        context.locale.toString(),
                      ).format(point.date),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBreakdownList extends StatelessWidget {
  const _StatusBreakdownList({required this.slices});

  final List<StatusSlice> slices;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return _EmptyHint(message: LocaleKeys.opsNoData.tr());
    }
    return Column(
      children: slices.map((slice) {
        final color = switch (slice.status) {
          OrderStatus.delivered => AppColors.success,
          OrderStatus.cancelled => AppColors.error,
          OrderStatus.onTheWay => const Color(0xFF5C6BC0),
          OrderStatus.waitingCourier => AppColors.warning,
          _ => AppColors.primary,
        };
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _ShareRow(
            label: OrderStatusUtils.label(slice.status),
            count: slice.count,
            share: slice.share,
            color: color,
          ),
        );
      }).toList(),
    );
  }
}

class _PaymentBreakdownList extends StatelessWidget {
  const _PaymentBreakdownList({required this.slices});

  final List<PaymentSlice> slices;

  @override
  Widget build(BuildContext context) {
    if (slices.isEmpty) {
      return _EmptyHint(message: LocaleKeys.opsNoData.tr());
    }
    const colors = [
      AppColors.primary,
      Color(0xFF00897B),
      Color(0xFF5C6BC0),
    ];
    return Column(
      children: [
        for (var i = 0; i < slices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _ShareRow(
              label: PaymentMethodUtils.label(slices[i].method),
              count: slices[i].count,
              share: slices[i].share,
              color: colors[i % colors.length],
              trailing: FormatUtils.currency(slices[i].revenue),
            ),
          ),
      ],
    );
  }
}

class _ShareRow extends StatelessWidget {
  const _ShareRow({
    required this.label,
    required this.count,
    required this.share,
    required this.color,
    this.trailing,
  });

  final String label;
  final int count;
  final double share;
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              trailing ?? '$count',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(width: 6),
            Text(
              '${(share * 100).round()}%',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 6,
            backgroundColor: color.withValues(alpha: 0.12),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PeakHoursChart extends StatelessWidget {
  const _PeakHoursChart({required this.buckets});

  final List<HourlyBucket> buckets;

  @override
  Widget build(BuildContext context) {
    final maxCount =
        buckets.map((b) => b.orderCount).fold<int>(0, math.max).clamp(1, 999);
    final peakHour = buckets.reduce(
      (a, b) => a.orderCount >= b.orderCount ? a : b,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (peakHour.orderCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              LocaleKeys.adminReportsPeakHourHint.tr(
                namedArgs: {
                  'hour': '${peakHour.hour.toString().padLeft(2, '0')}:00',
                  'count': '${peakHour.orderCount}',
                },
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final bucket in buckets)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: bucket.orderCount == 0
                                ? 0.04
                                : (bucket.orderCount / maxCount)
                                    .clamp(0.08, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: bucket.hour == peakHour.hour
                                    ? AppColors.primary
                                    : AppColors.primary
                                        .withValues(alpha: 0.35),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (bucket.hour % 3 == 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${bucket.hour}',
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontSize: 9,
                                      color: AppColors.textSecondary,
                                    ),
                          ),
                        ] else
                          const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BranchRankingList extends StatelessWidget {
  const _BranchRankingList({required this.rankings});

  final List<BranchRanking> rankings;

  @override
  Widget build(BuildContext context) {
    if (rankings.isEmpty) {
      return _EmptyHint(message: LocaleKeys.adminReportsNoOrdersInPeriod.tr());
    }

    return Column(
      children: [
        for (var i = 0; i < rankings.length; i++)
          _RankingTile(
            rank: i + 1,
            title: rankings[i].branchName,
            subtitle: LocaleKeys.adminReportsBranchSummary.tr(
              namedArgs: {
                'orders': '${rankings[i].orderCount}',
                'delivered': '${rankings[i].deliveredCount}',
                'cancelRate':
                    rankings[i].cancelRate.toStringAsFixed(1),
              },
            ),
            trailing: FormatUtils.currency(rankings[i].revenue),
            badge: rankings[i].avgDeliveryMinutes != null
                ? LocaleKeys.orderAuditMinutes.tr(
                    namedArgs: {
                      'minutes': '${rankings[i].avgDeliveryMinutes}',
                    },
                  )
                : null,
          ),
      ],
    );
  }
}

class _TopProductsList extends StatelessWidget {
  const _TopProductsList({required this.products});

  final Iterable<ProductRanking> products;

  @override
  Widget build(BuildContext context) {
    final list = products.toList();
    if (list.isEmpty) {
      return _EmptyHint(message: LocaleKeys.opsNoData.tr());
    }

    return Column(
      children: [
        for (var i = 0; i < list.length; i++)
          _RankingTile(
            rank: i + 1,
            title: localizedOrRaw(list[i].productNameKey),
            subtitle: LocaleKeys.adminReportsProductSold.tr(
              namedArgs: {'count': '${list[i].quantity}'},
            ),
            trailing: FormatUtils.currency(list[i].revenue),
          ),
      ],
    );
  }
}

class _RankingTile extends StatelessWidget {
  const _RankingTile({
    required this.rank,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.badge,
  });

  final int rank;
  final String title;
  final String subtitle;
  final String trailing;
  final String? badge;

  Color get _rankColor => switch (rank) {
        1 => const Color(0xFFFFB300),
        2 => const Color(0xFF90A4AE),
        3 => const Color(0xFFCD7F32),
        _ => AppColors.divider,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: rank <= 3
                  ? _rankColor.withValues(alpha: 0.18)
                  : AppColors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: rank <= 3 ? _rankColor : AppColors.divider,
              ),
            ),
            child: Text(
              '$rank',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: rank <= 3 ? _rankColor : AppColors.textSecondary,
                  ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                trailing,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
              ),
              if (badge != null)
                Text(
                  badge!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamPerformanceSection extends StatelessWidget {
  const _TeamPerformanceSection({required this.analytics});

  final OpsAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.opsStaffTitle.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (analytics.staffStats.isEmpty)
          _EmptyHint(message: LocaleKeys.opsNoData.tr())
        else
          ...analytics.staffStats.take(5).map(
                (s) => _TeamTile(
                  icon: Icons.person_outline,
                  title: s.userName,
                  subtitle: LocaleKeys.opsStaffOrders.tr(
                    namedArgs: {'count': '${s.orderCount}'},
                  ),
                ),
              ),
        const SizedBox(height: AppSpacing.md),
        Text(
          LocaleKeys.opsCourierTitle.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (analytics.courierStats.isEmpty)
          _EmptyHint(message: LocaleKeys.opsNoData.tr())
        else
          ...analytics.courierStats.take(5).map(
                (c) => _TeamTile(
                  icon: Icons.two_wheeler,
                  title: c.courierName,
                  subtitle: LocaleKeys.opsCourierSummary.tr(
                    namedArgs: {
                      'count': '${c.todayDeliveries}',
                      'avg': '${c.avgDeliveryMinutes}',
                      'min': '${c.minDeliveryMinutes}',
                      'max': '${c.maxDeliveryMinutes}',
                    },
                  ),
                ),
              ),
      ],
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
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
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
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

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
