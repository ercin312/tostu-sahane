import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/domain/entities/app_broadcast.dart';
import '../../../../../shared/presentation/providers/broadcast_providers.dart';

class CustomerNotificationDetailPage extends ConsumerStatefulWidget {
  const CustomerNotificationDetailPage({super.key, required this.broadcastId});

  final String broadcastId;

  @override
  ConsumerState<CustomerNotificationDetailPage> createState() =>
      _CustomerNotificationDetailPageState();
}

class _CustomerNotificationDetailPageState
    extends ConsumerState<CustomerNotificationDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(seenBroadcastsProvider.notifier).markAll([
        widget.broadcastId,
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(broadcastsProvider);
    final dateFormat = DateFormat('d MMMM yyyy HH:mm', context.locale.toString());

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.customerNotificationDetail.tr())),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: Text(LocaleKeys.customerNotificationMissing.tr()),
        ),
        data: (list) {
          AppBroadcast? item;
          for (final candidate in list) {
            if (candidate.id == widget.broadcastId) item = candidate;
          }
          if (item == null) {
            return Center(
              child: Text(LocaleKeys.customerNotificationMissing.tr()),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: Icon(
                    item.isCampaign
                        ? Icons.local_offer
                        : Icons.campaign_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    item.isCampaign
                        ? LocaleKeys.customerNotificationCampaign.tr()
                        : LocaleKeys.adminBroadcastKindAll.tr(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                dateFormat.format(item.createdAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                item.body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                    ),
              ),
              if (item.isCampaign) ...[
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: () => context.go(RoutePaths.customerHome),
                  icon: const Icon(Icons.restaurant_menu),
                  label: Text(LocaleKeys.customerNotificationOpenMenu.tr()),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
