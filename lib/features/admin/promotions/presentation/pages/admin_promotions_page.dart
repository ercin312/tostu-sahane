import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../shared/domain/entities/delivery_settings.dart';
import '../../../../../shared/domain/entities/promotion_campaign.dart';
import '../../../../../shared/presentation/providers/delivery_settings_provider.dart';
import '../../../../../shared/presentation/providers/promotion_providers.dart';
import '../widgets/promotion_campaign_editor.dart';

class AdminPromotionsPage extends ConsumerStatefulWidget {
  const AdminPromotionsPage({super.key});

  @override
  ConsumerState<AdminPromotionsPage> createState() => _AdminPromotionsPageState();
}

class _AdminPromotionsPageState extends ConsumerState<AdminPromotionsPage> {
  final _freeDeliveryController = TextEditingController();
  var _deliveryLoaded = false;
  var _savingDelivery = false;

  @override
  void dispose() {
    _freeDeliveryController.dispose();
    super.dispose();
  }

  void _ensureDeliveryLoaded(DeliverySettings settings) {
    if (_deliveryLoaded) return;
    _deliveryLoaded = true;
    _freeDeliveryController.text = settings.freeDeliveryMinOrder.toStringAsFixed(
      settings.freeDeliveryMinOrder == settings.freeDeliveryMinOrder.roundToDouble()
          ? 0
          : 0,
    );
  }

  Future<void> _saveDeliverySettings() async {
    final amount = double.tryParse(
      _freeDeliveryController.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminFreeDeliveryMinOrderInvalid.tr())),
      );
      return;
    }

    setState(() => _savingDelivery = true);
    try {
      await saveDeliverySettings(
        ref,
        DeliverySettings(freeDeliveryMinOrder: amount),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminPromotionsSaved.tr())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    } finally {
      if (mounted) setState(() => _savingDelivery = false);
    }
  }

  String _typeLabel(PromotionType type) => switch (type) {
        PromotionType.percentDiscount =>
          LocaleKeys.adminPromotionTypePercent.tr(),
        PromotionType.fixedDiscount => LocaleKeys.adminPromotionTypeFixed.tr(),
        PromotionType.freeDrinks =>
          LocaleKeys.adminPromotionTypeFreeDrinks.tr(),
      };

  String _campaignSubtitle(PromotionCampaign campaign) {
    final min = FormatUtils.currency(campaign.minOrderAmount);
    return switch (campaign.type) {
      PromotionType.percentDiscount =>
        '${campaign.value.toStringAsFixed(0)}% — min $min',
      PromotionType.fixedDiscount =>
        '${FormatUtils.currency(campaign.value)} — min $min',
      PromotionType.freeDrinks => 'min $min',
    };
  }

  @override
  Widget build(BuildContext context) {
    final deliveryAsync = ref.watch(deliverySettingsProvider);
    final campaignsAsync = ref.watch(promotionCampaignsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.adminPromotionsTitle.tr()),
        actions: const [RoleLogoutAction()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPromotionCampaignEditor(context, ref),
        icon: const Icon(Icons.add),
        label: Text(LocaleKeys.adminCampaignAdd.tr()),
      ),
      body: deliveryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
        data: (deliverySettings) {
          _ensureDeliveryLoaded(deliverySettings);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                LocaleKeys.adminPromotionsSubtitle.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        LocaleKeys.adminDeliverySettingsTitle.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _freeDeliveryController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText:
                              LocaleKeys.adminFreeDeliveryMinOrder.tr(),
                          hintText: '150',
                          helperText:
                              LocaleKeys.adminFreeDeliveryMinOrderHint.tr(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: _savingDelivery ? null : _saveDeliverySettings,
                        child: _savingDelivery
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(LocaleKeys.commonSave.tr()),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                LocaleKeys.adminCampaignsTitle.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              campaignsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => Text(LocaleKeys.commonError.tr()),
                data: (campaigns) {
                  if (campaigns.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.lg,
                      ),
                      child: Text(
                        LocaleKeys.adminCampaignsEmpty.tr(),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final campaign in campaigns)
                        Card(
                          child: ListTile(
                            leading: Icon(
                              campaign.isActive
                                  ? Icons.local_offer
                                  : Icons.local_offer_outlined,
                              color: campaign.isActive
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            title: Text(campaign.title),
                            subtitle: Text(
                              [
                                _typeLabel(campaign.type),
                                _campaignSubtitle(campaign),
                                if (campaign.hasCode) campaign.normalizedCode,
                                if (campaign.autoApply && !campaign.hasCode)
                                  LocaleKeys.adminPromotionAutoApply.tr(),
                              ].join(' · '),
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  await showPromotionCampaignEditor(
                                    context,
                                    ref,
                                    campaign: campaign,
                                  );
                                } else if (action == 'toggle') {
                                  await savePromotionCampaign(
                                    ref,
                                    campaign.copyWith(
                                      isActive: !campaign.isActive,
                                    ),
                                  );
                                } else if (action == 'delete') {
                                  await deletePromotionCampaign(
                                    ref,
                                    campaign.id,
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(LocaleKeys.commonEdit.tr()),
                                ),
                                PopupMenuItem(
                                  value: 'toggle',
                                  child: Text(
                                    campaign.isActive
                                        ? LocaleKeys.adminCampaignInactive.tr()
                                        : LocaleKeys.adminCampaignActive.tr(),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    LocaleKeys.commonRemove.tr(),
                                    style: const TextStyle(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
