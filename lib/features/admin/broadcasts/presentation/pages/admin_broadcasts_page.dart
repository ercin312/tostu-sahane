import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/domain/entities/app_broadcast.dart';
import '../../../../../shared/domain/entities/pickup_settings.dart';
import '../../../../../shared/domain/entities/promotion_campaign.dart';
import '../../../../../shared/presentation/providers/broadcast_providers.dart';
import '../../../../../shared/presentation/providers/pickup_settings_provider.dart';
import '../../../../../shared/presentation/providers/promotion_providers.dart';
import '../../../../../shared/presentation/providers/repository_providers.dart';

class AdminBroadcastsPage extends ConsumerStatefulWidget {
  const AdminBroadcastsPage({super.key});

  @override
  ConsumerState<AdminBroadcastsPage> createState() =>
      _AdminBroadcastsPageState();
}

class _AdminBroadcastsPageState extends ConsumerState<AdminBroadcastsPage> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  BroadcastKind _kind = BroadcastKind.announcement;
  String? _campaignId;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  List<PromotionCampaign> _campaigns(PickupSettings? pickup) {
    final delivery = ref.watch(promotionCampaignsProvider).valueOrNull ?? [];
    final extra = pickup?.campaigns ?? const <PromotionCampaign>[];
    final byId = <String, PromotionCampaign>{
      for (final campaign in [...delivery, ...extra]) campaign.id: campaign,
    };
    final items = byId.values.toList()
      ..sort((a, b) => a.title.compareTo(b.title));
    return items;
  }

  void _applyCampaign(PromotionCampaign campaign) {
    setState(() {
      _campaignId = campaign.id;
      _title.text = campaign.title;
      final detail = campaign.description.trim();
      _body.text = detail.isEmpty ? campaign.title : detail;
    });
  }

  Future<void> _send(List<PromotionCampaign> campaigns) async {
    final title = _title.text.trim();
    final body = _body.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _snack(LocaleKeys.adminBroadcastInvalid.tr());
      return;
    }
    if (_kind == BroadcastKind.campaign &&
        (_campaignId == null ||
            !campaigns.any((item) => item.id == _campaignId))) {
      _snack(LocaleKeys.adminBroadcastNoCampaign.tr());
      return;
    }

    setState(() => _sending = true);
    try {
      final broadcast = AppBroadcast(
        id: 'bc_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        kind: _kind,
        campaignId:
            _kind == BroadcastKind.campaign ? _campaignId : null,
        createdAt: DateTime.now(),
      );
      await ref.read(broadcastRepositoryProvider).createBroadcast(broadcast);
      if (!mounted) return;
      _title.clear();
      _body.clear();
      setState(() => _campaignId = null);
      _snack(LocaleKeys.adminBroadcastSent.tr());
    } catch (_) {
      if (mounted) _snack(LocaleKeys.adminBroadcastInvalid.tr());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pickup = ref.watch(pickupSettingsProvider).valueOrNull;
    final campaigns = _campaigns(pickup);
    final history = ref.watch(broadcastsProvider).valueOrNull ?? [];
    final dateFormat = DateFormat('d MMM yyyy HH:mm', context.locale.toString());

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.adminBroadcastsTitle.tr())),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            LocaleKeys.adminBroadcastsHint.tr(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<BroadcastKind>(
            segments: [
              ButtonSegment(
                value: BroadcastKind.announcement,
                label: Text(LocaleKeys.adminBroadcastKindAll.tr()),
                icon: const Icon(Icons.campaign_outlined),
              ),
              ButtonSegment(
                value: BroadcastKind.campaign,
                label: Text(LocaleKeys.adminBroadcastKindCampaign.tr()),
                icon: const Icon(Icons.local_offer_outlined),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (value) {
              setState(() => _kind = value.first);
            },
          ),
          if (_kind == BroadcastKind.campaign) ...[
            const SizedBox(height: AppSpacing.md),
            if (campaigns.isEmpty)
              Text(LocaleKeys.adminBroadcastNoCampaign.tr())
            else
              DropdownButtonFormField<String>(
              value: campaigns.any((item) => item.id == _campaignId)
                  ? _campaignId
                  : null,
              decoration: InputDecoration(
                labelText: LocaleKeys.adminBroadcastCampaign.tr(),
              ),
              items: [
                for (final campaign in campaigns)
                  DropdownMenuItem(
                    value: campaign.id,
                    child: Text(campaign.title),
                  ),
              ],
              onChanged: (id) {
                for (final campaign in campaigns) {
                  if (campaign.id == id) _applyCampaign(campaign);
                }
              },
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: LocaleKeys.adminBroadcastTitle.tr(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _body,
            minLines: 4,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: LocaleKeys.adminBroadcastBody.tr(),
              hintText: LocaleKeys.adminBroadcastBodyHint.tr(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _sending ? null : () => _send(campaigns),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(LocaleKeys.adminBroadcastSend.tr()),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            LocaleKeys.adminBroadcastHistory.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (history.isEmpty)
            Text(LocaleKeys.adminBroadcastEmpty.tr())
          else
            for (final item in history)
              Card(
                child: ListTile(
                  leading: Icon(
                    item.isCampaign
                        ? Icons.local_offer
                        : Icons.notifications_active,
                    color: AppColors.primary,
                  ),
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.isCampaign ? LocaleKeys.customerNotificationCampaign.tr() : LocaleKeys.adminBroadcastKindAll.tr()} · ${dateFormat.format(item.createdAt.toLocal())}',
                  ),
                  onTap: () => context.push(
                    RoutePaths.broadcastDetail(item.id),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
