import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/presentation/providers/broadcast_providers.dart';

class CustomerNotificationsPage extends ConsumerStatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  ConsumerState<CustomerNotificationsPage> createState() =>
      _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState
    extends ConsumerState<CustomerNotificationsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final items = ref.read(broadcastsProvider).valueOrNull ?? [];
      ref.read(seenBroadcastsProvider.notifier).markAll(
            items.map((item) => item.id),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(broadcastsProvider).valueOrNull ?? [];
    final seen = ref.watch(seenBroadcastsProvider);
    ref.listen(broadcastsProvider, (previous, next) {
      final loaded = next.valueOrNull;
      if (loaded == null || loaded.isEmpty) return;
      ref.read(seenBroadcastsProvider.notifier).markAll(
            loaded.map((item) => item.id),
          );
    });
    final dateFormat = DateFormat('d MMM yyyy HH:mm', context.locale.toString());

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.customerNotificationsTitle.tr())),
      body: items.isEmpty
          ? Center(child: Text(LocaleKeys.customerNotificationsEmpty.tr()))
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = items[index];
                final unread = !seen.contains(item.id);
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: unread
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.12),
                      child: Icon(
                        item.isCampaign
                            ? Icons.local_offer
                            : Icons.notifications,
                        color: unread ? AppColors.white : AppColors.primary,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${item.isCampaign ? LocaleKeys.customerNotificationCampaign.tr() : LocaleKeys.adminBroadcastKindAll.tr()}\n${dateFormat.format(item.createdAt.toLocal())}',
                    ),
                    isThreeLine: true,
                    onTap: () => context.push(
                      RoutePaths.broadcastDetail(item.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
