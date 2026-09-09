import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/promotion_utils.dart';
import '../../../../../shared/domain/entities/promotion_campaign.dart';
import '../../../../../shared/presentation/providers/promotion_providers.dart';
import '../../../checkout/presentation/providers/coupon_provider.dart';
import '../providers/cart_provider.dart';

Future<void> showCampaignPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => const _CampaignPickerSheet(),
  );
}

class _CampaignPickerSheet extends ConsumerStatefulWidget {
  const _CampaignPickerSheet();

  @override
  ConsumerState<_CampaignPickerSheet> createState() =>
      _CampaignPickerSheetState();
}

class _CampaignPickerSheetState extends ConsumerState<_CampaignPickerSheet> {
  final _codeController = TextEditingController();
  String? _codeError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String _amountLabel(PromotionCampaign campaign, double computed) {
    return switch (campaign.type) {
      PromotionType.fixedDiscount => FormatUtils.currency(campaign.value),
      PromotionType.percentDiscount =>
        computed > 0
            ? FormatUtils.currency(computed)
            : '%${campaign.value.toStringAsFixed(0)}',
      PromotionType.freeDrinks => LocaleKeys.adminPromotionTypeFreeDrinks.tr(),
    };
  }

  String _metaLine(PromotionCampaign campaign) {
    final min = FormatUtils.currency(campaign.minOrderAmount);
    final expiry = campaign.expiresAt;
    if (expiry == null) {
      return LocaleKeys.campaignPickerMinOnly.tr(namedArgs: {'amount': min});
    }
    final date = DateFormat('d MMM yyyy', 'tr_TR').format(expiry.toLocal());
    return LocaleKeys.campaignPickerMinUntil.tr(
      namedArgs: {'amount': min, 'date': date},
    );
  }

  Future<void> _applyCode() async {
    final error = await ref.read(couponNotifierProvider).apply(
          _codeController.text,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() => _codeError = error.tr());
      return;
    }
    Navigator.pop(context);
  }

  void _applyCampaign(PromotionCampaign campaign, {required bool eligible}) {
    if (!eligible) return;
    ref.read(couponNotifierProvider).applyCampaign(campaign);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final campaigns = ref.watch(activePromotionCampaignsProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    final cart = ref.watch(cartProvider);
    final categories = ref.watch(productCategoryMapProvider);
    final selected = ref.watch(appliedCheckoutDiscountProvider);
    final height = MediaQuery.sizeOf(context).height * 0.92;

    final offered = <PromotionCampaign>[];
    final invalid = <PromotionCampaign>[];
    var bestId = '';
    var bestAmount = 0.0;

    for (final campaign in campaigns) {
      if (!PromotionUtils.canOfferInPicker(campaign)) {
        if (campaign.isActive) invalid.add(campaign);
        continue;
      }
      final applies = PromotionUtils.appliesToCart(
        campaign: campaign,
        cartItems: cart,
        productCategories: categories,
      );
      if (!applies) {
        invalid.add(campaign);
        continue;
      }
      offered.add(campaign);
      final amount = PromotionUtils.discountFor(
        campaign: campaign,
        subtotal: subtotal,
        cartItems: cart,
        productCategories: categories,
      );
      if (amount > bestAmount) {
        bestAmount = amount;
        bestId = campaign.id;
      }
    }

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
                Expanded(
                  child: Text(
                    LocaleKeys.campaignPickerTitle.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: LocaleKeys.campaignPickerEnterCode.tr(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    errorText: _codeError,
                    suffixIcon: TextButton(
                      onPressed: _applyCode,
                      child: Text(LocaleKeys.checkoutCouponApply.tr()),
                    ),
                  ),
                  onSubmitted: (_) => _applyCode(),
                ),
                const SizedBox(height: 20),
                Text(
                  LocaleKeys.campaignPickerSelect.tr(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 10),
                if (offered.isEmpty)
                  Text(
                    LocaleKeys.campaignPickerEmpty.tr(),
                    style: const TextStyle(color: AppColors.textSecondary),
                  )
                else
                  ...offered.map((campaign) {
                    final needed = PromotionUtils.amountStillNeeded(
                      campaign: campaign,
                      subtotal: subtotal,
                    );
                    final computed = PromotionUtils.discountFor(
                      campaign: campaign,
                      subtotal: subtotal,
                      cartItems: cart,
                      productCategories: categories,
                    );
                    final eligible = needed <= 0 && computed > 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CouponCard(
                        campaign: campaign,
                        amountLabel: _amountLabel(campaign, computed),
                        meta: _metaLine(campaign),
                        selected: selected?.campaignId == campaign.id,
                        eligible: eligible,
                        best: campaign.id == bestId && eligible,
                        neededLabel: needed > 0
                            ? LocaleKeys.campaignPickerNeedMore.tr(
                                namedArgs: {
                                  'amount': FormatUtils.currency(needed),
                                },
                              )
                            : null,
                        onApply: () => _applyCampaign(
                          campaign,
                          eligible: eligible,
                        ),
                      ),
                    );
                  }),
                if (invalid.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    LocaleKeys.campaignPickerInvalid.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...invalid.map(
                    (campaign) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CouponCard(
                        campaign: campaign,
                        amountLabel: _amountLabel(campaign, 0),
                        meta: _metaLine(campaign),
                        selected: false,
                        eligible: false,
                        invalid: true,
                        onApply: () {},
                        onDetails: () {
                          showDialog<void>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(campaign.title),
                              content: Text(_metaLine(campaign)),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(LocaleKeys.commonCancel.tr()),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({
    required this.campaign,
    required this.amountLabel,
    required this.meta,
    required this.selected,
    required this.eligible,
    required this.onApply,
    this.neededLabel,
    this.best = false,
    this.invalid = false,
    this.onDetails,
  });

  final PromotionCampaign campaign;
  final String amountLabel;
  final String meta;
  final bool selected;
  final bool eligible;
  final bool best;
  final bool invalid;
  final String? neededLabel;
  final VoidCallback onApply;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (neededLabel != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              neededLabel!,
              style: const TextStyle(
                color: Color(0xFFD32F4A),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : const Color(0xFFE6E6E6),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(
                      Icons.confirmation_number,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      campaign.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (best)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        LocaleKeys.campaignPickerBest.tr(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (campaign.remainingUses != null)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F3F3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        LocaleKeys.campaignPickerRemaining.tr(
                          namedArgs: {'count': '${campaign.remainingUses}'},
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    amountLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  if (campaign.hasCode) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.info_outline, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      campaign.normalizedCode,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF6F6F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (invalid)
                    OutlinedButton(
                      onPressed: onDetails,
                      child: Text(LocaleKeys.campaignPickerDetails.tr()),
                    )
                  else
                    FilledButton(
                      onPressed: eligible ? onApply : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        disabledBackgroundColor: const Color(0xFFEDEDED),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: Text(
                        selected
                            ? LocaleKeys.campaignPickerApplied.tr()
                            : LocaleKeys.checkoutCouponApply.tr(),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sepet ve ödeme ekranında kampanya satırı.
class CampaignPickerTile extends ConsumerWidget {
  const CampaignPickerTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appliedCheckoutDiscountProvider);
    final auto = ref.watch(autoCheckoutDiscountProvider);
    final discount = ref.watch(checkoutDiscountProvider);
    final label = selected?.label ??
        (discount > 0 ? auto?.label : null) ??
        LocaleKeys.campaignPickerCartCta.tr();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => showCampaignPicker(context, ref),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE6E6E6)),
          ),
          child: Row(
            children: [
              const Icon(Icons.confirmation_number, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (discount > 0)
                      Text(
                        FormatUtils.currency(discount),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              if (selected != null)
                TextButton(
                  onPressed: () => ref.read(couponNotifierProvider).clear(),
                  child: Text(LocaleKeys.campaignPickerRemove.tr()),
                )
              else
                const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
