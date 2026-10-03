import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../shared/domain/entities/delivery_settings.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/promotion_campaign.dart';
import '../../../../../shared/presentation/providers/delivery_settings_provider.dart';
import '../../../../../shared/presentation/providers/promotion_providers.dart';
import '../../../../customer/home/presentation/providers/branch_provider.dart';
import '../widgets/promotion_campaign_editor.dart';

class AdminPromotionsPage extends ConsumerStatefulWidget {
  const AdminPromotionsPage({super.key});

  @override
  ConsumerState<AdminPromotionsPage> createState() => _AdminPromotionsPageState();
}

class _AdminPromotionsPageState extends ConsumerState<AdminPromotionsPage> {
  final _freeDeliveryController = TextEditingController();
  final _belowMinFeeController = TextEditingController();
  final _upsellSearchController = TextEditingController();
  var _upsellIds = <String>[];
  var _deliveryLoaded = false;
  var _savingDelivery = false;

  @override
  void dispose() {
    _freeDeliveryController.dispose();
    _belowMinFeeController.dispose();
    _upsellSearchController.dispose();
    super.dispose();
  }

  void _ensureDeliveryLoaded(DeliverySettings settings) {
    if (_deliveryLoaded) return;
    _deliveryLoaded = true;
    _freeDeliveryController.text = _amountText(settings.freeDeliveryMinOrder);
    _belowMinFeeController.text = _amountText(settings.belowMinimumDeliveryFee);
    _upsellIds = List<String>.of(settings.upsellProductIds);
  }

  String _amountText(double value) {
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  }

  Future<void> _saveDeliverySettings() async {
    final amount = double.tryParse(
      _freeDeliveryController.text.trim().replaceAll(',', '.'),
    );
    final fee = double.tryParse(
      _belowMinFeeController.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || amount < 0 || fee == null || fee < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminFreeDeliveryMinOrderInvalid.tr())),
      );
      return;
    }

    setState(() => _savingDelivery = true);
    try {
      await saveDeliverySettings(
        ref,
        DeliverySettings(
          freeDeliveryMinOrder: amount,
          belowMinimumDeliveryFee: fee,
          upsellProductIds: _upsellIds,
        ),
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

  String _typeLabel(PromotionType type) => type.localeKey.tr();

  String _campaignSubtitle(PromotionCampaign campaign) {
    final parts = <String>[_typeLabel(campaign.type)];
    if (campaign.type == PromotionType.percentDiscount) {
      parts.add('%${campaign.value.toStringAsFixed(0)}');
    } else if (campaign.type == PromotionType.fixedDiscount) {
      parts.add(FormatUtils.currency(campaign.value));
    } else if (campaign.type == PromotionType.buyXGetY) {
      parts.add('${campaign.buyQuantity} al ${campaign.freeQuantity}');
    }
    if (campaign.minOrderAmount > 0) {
      parts.add('min ${FormatUtils.currency(campaign.minOrderAmount)}');
    }
    if (campaign.hasCode) parts.add(campaign.normalizedCode);
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final deliveryAsync = ref.watch(deliverySettingsProvider);
    final campaignsAsync = ref.watch(promotionCampaignsProvider);
    final products = ref.watch(productsProvider).value ?? const <Product>[];

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
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _belowMinFeeController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: LocaleKeys.adminBelowMinDeliveryFee.tr(),
                          hintText: '30',
                          helperText:
                              LocaleKeys.adminBelowMinDeliveryFeeHint.tr(),
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
              _UpsellPickerCard(
                products: products,
                selectedIds: _upsellIds,
                searchController: _upsellSearchController,
                onChanged: (ids) => setState(() => _upsellIds = ids),
                saving: _savingDelivery,
                onSave: _saveDeliverySettings,
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
                                if (campaign.firstOrderOnly)
                                  LocaleKeys.adminPromotionFirstOrder.tr(),
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

class _UpsellPickerCard extends StatelessWidget {
  const _UpsellPickerCard({
    required this.products,
    required this.selectedIds,
    required this.searchController,
    required this.onChanged,
    required this.saving,
    required this.onSave,
  });

  final List<Product> products;
  final List<String> selectedIds;
  final TextEditingController searchController;
  final ValueChanged<List<String>> onChanged;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final visible = products.where((product) {
      if (query.isEmpty) return true;
      return localizedOrRaw(product.nameKey).toLowerCase().contains(query);
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              LocaleKeys.adminCartUpsellTitle.tr(),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              LocaleKeys.adminCartUpsellHint.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: searchController,
              onChanged: (_) => onChanged(List<String>.of(selectedIds)),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: LocaleKeys.customerSearchMenu.tr(),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (visible.isEmpty)
              const SizedBox(height: AppSpacing.sm)
            else
              SizedBox(
                height: 280,
                child: ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final product = visible[index];
                    final checked = selectedIds.contains(product.id);
                    return CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: checked,
                      title: Text(localizedOrRaw(product.nameKey)),
                      subtitle: Text(FormatUtils.currency(product.price)),
                      onChanged: (value) {
                        final next = List<String>.of(selectedIds);
                        if (value ?? false) {
                          if (!next.contains(product.id)) next.add(product.id);
                        } else {
                          next.remove(product.id);
                        }
                        onChanged(next);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: saving ? null : onSave,
              child: saving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(LocaleKeys.commonSave.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
