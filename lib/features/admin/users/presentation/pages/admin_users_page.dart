import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../presentation/helpers/admin_operational_data_purge_helper.dart';
import '../../../presentation/providers/admin_provider.dart';
import '../../../presentation/widgets/admin_form_dialogs.dart';

class AdminUsersPage extends ConsumerWidget {
  const AdminUsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.adminUsersTitle.tr())),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final user = list[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: user.isActive
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : AppColors.divider,
                          child: Icon(
                            Icons.person,
                            color: user.isActive
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizedOrRaw(user.name),
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                user.phone,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                              if (user.branchId != null)
                                Text(
                                  user.branchId!,
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
                        Chip(
                          label: Text(adminRoleLabel(user.role)),
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.08),
                        ),
                        if (canPurgeOperationalDataForUser(user))
                          PopupMenuButton<String>(
                            tooltip: LocaleKeys.opsDataPurgeUserAction.tr(),
                            icon: Icon(
                              Icons.more_vert,
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            onSelected: (value) async {
                              if (value == 'purge') {
                                await purgeOperationalDataForAdminUser(
                                  context: context,
                                  ref: ref,
                                  user: user,
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'purge',
                                child: Text(
                                  LocaleKeys.opsDataPurgeUserAction.tr(),
                                  style: const TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () =>
                              showUserFormDialog(context, ref, user: user),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: Text(LocaleKeys.commonEdit.tr()),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final confirm =
                                await showAdminDeleteConfirm(context);
                            if (confirm == true) {
                              await ref
                                  .read(adminUsersProvider.notifier)
                                  .deleteUser(user.id);
                            }
                          },
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: AppColors.error),
                          label: Text(
                            LocaleKeys.commonRemove.tr(),
                            style: const TextStyle(color: AppColors.error),
                          ),
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
        onPressed: () => showUserFormDialog(context, ref),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
