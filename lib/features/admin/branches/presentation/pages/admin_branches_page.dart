import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/utils/branch_hours_utils.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/domain/entities/branch.dart';
import '../../../../../shared/domain/entities/geo_point.dart';
import '../../../presentation/providers/admin_provider.dart';
import '../../../presentation/widgets/admin_form_dialogs.dart';

class AdminBranchesPage extends ConsumerWidget {
  const AdminBranchesPage({super.key});

  String _zoneSummary(Branch branch) {
    return switch (branch.deliveryZoneMode) {
      DeliveryZoneMode.radius => LocaleKeys.adminZoneSummaryRadius.tr(
          namedArgs: {'km': branch.deliveryRadiusKm.toStringAsFixed(1)},
        ),
      DeliveryZoneMode.polygon => LocaleKeys.adminZoneSummaryPolygon.tr(
          namedArgs: {'count': '${branch.deliveryPolygon.length}'},
        ),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(adminBranchesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.adminBranchesTitle.tr())),
      body: branches.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
        data: (list) => list.isEmpty
            ? Center(child: Text(LocaleKeys.adminNoBranches.tr()))
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final branch = list[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.1),
                                child: const Icon(
                                  Icons.store,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      branch.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    Text(
                                      branch.address,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(
                                branch.isOpenNow
                                    ? Icons.schedule
                                    : Icons.schedule_outlined,
                                size: 16,
                                color: branch.isOpenNow
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                LocaleKeys.branchHoursLabel.tr(
                                  namedArgs: {
                                    'hours': BranchHoursUtils.formatRange(
                                      branch.openTime,
                                      branch.closeTime,
                                    ),
                                  },
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              Icon(
                                branch.deliveryZoneMode ==
                                        DeliveryZoneMode.radius
                                    ? Icons.radio_button_checked
                                    : Icons.pentagon_outlined,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _zoneSummary(branch),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => context.push(
                                  RoutePaths.adminBranchDeliveryZone(branch.id),
                                ),
                                icon: const Icon(Icons.map_outlined, size: 18),
                                label: Text(LocaleKeys.adminZoneEdit.tr()),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => showBranchFormDialog(
                                  context,
                                  ref,
                                  branch: branch,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.error),
                                onPressed: () async {
                                  final confirm =
                                      await showAdminDeleteConfirm(context);
                                  if (confirm == true) {
                                    await ref
                                        .read(adminBranchesProvider.notifier)
                                        .deleteBranch(branch.id);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showBranchFormDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
