import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/locale_keys.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/format_utils.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../shared/domain/entities/courier_cash_remittance.dart';
import '../../shared/presentation/providers/cash_remittance_providers.dart';

class CashRemittanceReviewPage extends ConsumerWidget {
  const CashRemittanceReviewPage({
    super.key,
    required this.title,
    required this.remittancesAsync,
    this.showBranchName = false,
    this.branchNameById = const {},
  });

  final String title;
  final AsyncValue<List<CourierCashRemittance>> remittancesAsync;
  final bool showBranchName;
  final Map<String, String> branchNameById;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: remittancesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(LocaleKeys.commonError.tr())),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Text(LocaleKeys.cashRemittanceEmpty.tr()),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              return _RemittanceCard(
                remittance: items[index],
                showBranchName: showBranchName,
                branchName: branchNameById[items[index].branchId],
                onApprove: items[index].isPending
                    ? () => _review(
                          context,
                          ref,
                          items[index],
                          approve: true,
                        )
                    : null,
                onReject: items[index].isPending
                    ? () => _review(
                          context,
                          ref,
                          items[index],
                          approve: false,
                        )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    CourierCashRemittance remittance, {
    required bool approve,
  }) async {
    String? rejectionReason;
    if (!approve) {
      rejectionReason = await _askRejectionReason(context);
      if (rejectionReason == null) return;
    } else {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(LocaleKeys.cashRemittanceApproveTitle.tr()),
          content: Text(
            LocaleKeys.cashRemittanceApproveMessage.tr(
              namedArgs: {
                'name': remittance.courierName,
                'amount': FormatUtils.currency(remittance.amount),
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(LocaleKeys.commonCancel.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(LocaleKeys.commonOk.tr()),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    final auth = ref.read(authProvider);
    if (auth == null) return;

    final repo = ref.read(courierCashRemittanceRepositoryProvider);
    try {
      if (approve) {
        await repo.approve(
          remittanceId: remittance.id,
          reviewerId: auth.user.id,
          reviewerName: auth.user.name,
        );
      } else {
        await repo.reject(
          remittanceId: remittance.id,
          reviewerId: auth.user.id,
          reviewerName: auth.user.name,
          rejectionReason: rejectionReason,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? LocaleKeys.cashRemittanceApproved.tr()
                  : LocaleKeys.cashRemittanceRejected.tr(),
            ),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.commonError.tr())),
        );
      }
    }
  }

  Future<String?> _askRejectionReason(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.cashRemittanceRejectTitle.tr()),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: LocaleKeys.cashRemittanceRejectReason.tr(),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(LocaleKeys.commonOk.tr()),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

class _RemittanceCard extends StatelessWidget {
  const _RemittanceCard({
    required this.remittance,
    required this.showBranchName,
    this.branchName,
    this.onApprove,
    this.onReject,
  });

  final CourierCashRemittance remittance;
  final bool showBranchName;
  final String? branchName;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (remittance.status) {
      CourierCashRemittanceStatus.pending => AppColors.warning,
      CourierCashRemittanceStatus.approved => AppColors.success,
      CourierCashRemittanceStatus.rejected => AppColors.error,
    };
    final statusLabel = switch (remittance.status) {
      CourierCashRemittanceStatus.pending =>
        LocaleKeys.cashRemittanceStatusPending.tr(),
      CourierCashRemittanceStatus.approved =>
        LocaleKeys.cashRemittanceStatusApproved.tr(),
      CourierCashRemittanceStatus.rejected =>
        LocaleKeys.cashRemittanceStatusRejected.tr(),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    remittance.courierName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (showBranchName && branchName != null) ...[
              const SizedBox(height: 4),
              Text(
                branchName!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              FormatUtils.currency(remittance.amount),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd.MM.yyyy HH:mm').format(remittance.requestedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (remittance.courierNote != null &&
                remittance.courierNote!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                LocaleKeys.cashRemittanceCourierNote.tr(
                  namedArgs: {'note': remittance.courierNote!},
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (remittance.rejectionReason != null &&
                remittance.rejectionReason!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                LocaleKeys.cashRemittanceRejectReasonDisplay.tr(
                  namedArgs: {'reason': remittance.rejectionReason!},
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.error,
                    ),
              ),
            ],
            if (onApprove != null || onReject != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      child: Text(LocaleKeys.cashRemittanceReject.tr()),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onApprove,
                      child: Text(LocaleKeys.cashRemittanceApprove.tr()),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String remittanceStatusLabel(CourierCashRemittanceStatus status) {
  return switch (status) {
    CourierCashRemittanceStatus.pending =>
      LocaleKeys.cashRemittanceStatusPending.tr(),
    CourierCashRemittanceStatus.approved =>
      LocaleKeys.cashRemittanceStatusApproved.tr(),
    CourierCashRemittanceStatus.rejected =>
      LocaleKeys.cashRemittanceStatusRejected.tr(),
  };
}

Color remittanceStatusColor(CourierCashRemittanceStatus status) {
  return switch (status) {
    CourierCashRemittanceStatus.pending => AppColors.warning,
    CourierCashRemittanceStatus.approved => AppColors.success,
    CourierCashRemittanceStatus.rejected => AppColors.error,
  };
}
