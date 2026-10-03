import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../shared/domain/entities/pickup_settings.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/promotion_campaign.dart';
import '../../../../../shared/presentation/providers/pickup_settings_provider.dart';
import '../../../../customer/home/presentation/providers/branch_provider.dart';
import '../../../promotions/presentation/widgets/promotion_campaign_editor.dart';

class AdminPickupPage extends ConsumerStatefulWidget {
  const AdminPickupPage({super.key});

  @override
  ConsumerState<AdminPickupPage> createState() => _AdminPickupPageState();
}

class _AdminPickupPageState extends ConsumerState<AdminPickupPage> {
  final _badgeController = TextEditingController();
  final _headlineController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _minutesController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _priceControllers = <String, TextEditingController>{};

  var _loaded = false;
  var _enabled = true;
  var _saving = false;

  @override
  void dispose() {
    _badgeController.dispose();
    _headlineController.dispose();
    _subtitleController.dispose();
    _minutesController.dispose();
    _minOrderController.dispose();
    for (final controller in _priceControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _ensureLoaded(PickupSettings settings, List<Product> products) {
    if (!_loaded) {
      _loaded = true;
      _enabled = settings.enabled;
      _badgeController.text = settings.badgeText;
      _headlineController.text = settings.headline;
      _subtitleController.text = settings.subtitle;
      _minutesController.text = '${settings.readyMinutes}';
      _minOrderController.text = settings.minOrderAmount == 0
          ? '0'
          : settings.minOrderAmount.toStringAsFixed(
              settings.minOrderAmount == settings.minOrderAmount.roundToDouble()
                  ? 0
                  : 2,
            );
    }
    for (final product in products) {
      _priceControllers.putIfAbsent(product.id, () {
        final override = settings.productPrices[product.id];
        return TextEditingController(
          text: override == null
              ? ''
              : override.toStringAsFixed(
                  override == override.roundToDouble() ? 0 : 2,
                ),
        );
      });
    }
  }

  TextEditingController _priceController(Product product) {
    return _priceControllers.putIfAbsent(
      product.id,
      () => TextEditingController(),
    );
  }

  PickupSettings _withDraft(PickupSettings current) {
    final minutes = int.tryParse(_minutesController.text.trim());
    final minOrder = double.tryParse(
      _minOrderController.text.trim().replaceAll(',', '.'),
    );
    final prices = <String, double>{};
    for (final entry in _priceControllers.entries) {
      final raw = entry.value.text.trim().replaceAll(',', '.');
      if (raw.isEmpty) continue;
      final value = double.tryParse(raw);
      if (value == null || value < 0) continue;
      prices[entry.key] = value;
    }
    return current.copyWith(
      enabled: _enabled,
      badgeText: _badgeController.text.trim(),
      headline: _headlineController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      readyMinutes: (minutes != null && minutes >= 5)
          ? minutes
          : current.readyMinutes,
      minOrderAmount: (minOrder != null && minOrder >= 0)
          ? minOrder
          : current.minOrderAmount,
      productPrices: prices,
    );
  }

  Future<void> _save(PickupSettings current, List<Product> products) async {
    final minutes = int.tryParse(_minutesController.text.trim());
    final minOrder = double.tryParse(
      _minOrderController.text.trim().replaceAll(',', '.'),
    );
    if (minutes == null || minutes < 5 || minOrder == null || minOrder < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminPromotionInvalid.tr())),
      );
      return;
    }

    for (final product in products) {
      final raw = _priceController(product).text.trim().replaceAll(',', '.');
      if (raw.isEmpty) continue;
      final value = double.tryParse(raw);
      if (value == null || value < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.adminPromotionInvalid.tr())),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final latest = ref.read(pickupSettingsProvider).valueOrNull ?? current;
      await savePickupSettings(ref, _withDraft(latest));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminPickupSaved.tr())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _upsertCampaign(PromotionCampaign campaign) async {
    final current = _withDraft(
      ref.read(pickupSettingsProvider).valueOrNull ?? PickupSettings.defaults,
    );
    final exists = current.campaigns.any((item) => item.id == campaign.id);
    final next = exists
        ? [
            for (final item in current.campaigns)
              if (item.id == campaign.id) campaign else item,
          ]
        : [...current.campaigns, campaign];
    await savePickupSettings(ref, current.copyWith(campaigns: next));
  }

  Future<void> _deleteCampaign(PromotionCampaign campaign) async {
    final loaded = ref.read(pickupSettingsProvider).valueOrNull;
    if (loaded == null) return;
    final current = _withDraft(loaded);
    await savePickupSettings(
      ref,
      current.copyWith(
        campaigns: current.campaigns
            .where((item) => item.id != campaign.id)
            .toList(),
      ),
    );
  }

  String _campaignSubtitle(PromotionCampaign campaign) {
    final parts = <String>[campaign.type.localeKey.tr()];
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
    if (campaign.firstOrderOnly) {
      parts.add(LocaleKeys.adminPromotionFirstOrder.tr());
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(pickupSettingsProvider);
    final products = ref.watch(productsProvider).value ?? const <Product>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.adminPickupTitle.tr()),
        actions: const [RoleLogoutAction()],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
        data: (settings) {
          _ensureLoaded(settings, products);
          final sellable =
              products.where((product) => product.isAvailable).toList();
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                LocaleKeys.adminPickupSubtitle.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(LocaleKeys.adminPickupEnabled.tr()),
                subtitle: Text(LocaleKeys.adminPickupEnabledHint.tr()),
                value: _enabled,
                onChanged: (value) => setState(() => _enabled = value),
              ),
              TextField(
                controller: _badgeController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminPickupBadge.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _headlineController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminPickupHeadline.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _subtitleController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminPickupSubtitleField.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _minutesController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminPickupReadyMinutes.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _minOrderController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: LocaleKeys.adminPickupMinOrder.tr(),
                  helperText: LocaleKeys.adminPickupMinOrderHint.tr(),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                LocaleKeys.adminPickupPricesTitle.tr(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                LocaleKeys.adminPickupPricesHint.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final product in sellable)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(localizedOrRaw(product.nameKey)),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        FormatUtils.currency(product.price),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _priceController(product),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            labelText: LocaleKeys.adminPickupPrice.tr(),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: _saving ? null : () => _save(settings, sellable),
                child: Text(
                  _saving
                      ? LocaleKeys.commonLoading.tr()
                      : LocaleKeys.adminPickupSave.tr(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      LocaleKeys.adminPickupCampaignsTitle.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => showPromotionCampaignEditor(
                      context,
                      ref,
                      persist: _upsertCampaign,
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(LocaleKeys.adminCampaignAdd.tr()),
                  ),
                ],
              ),
              Text(
                LocaleKeys.adminPickupCampaignsHint.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (settings.campaigns.isEmpty)
                Text(LocaleKeys.adminPickupCampaignEmpty.tr())
              else
                for (final campaign in settings.campaigns)
                  Card(
                    child: ListTile(
                      title: Text(campaign.title),
                      subtitle: Text(_campaignSubtitle(campaign)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => showPromotionCampaignEditor(
                              context,
                              ref,
                              campaign: campaign,
                              persist: _upsertCampaign,
                            ),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _deleteCampaign(campaign),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
