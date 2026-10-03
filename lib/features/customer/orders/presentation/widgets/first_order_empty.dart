import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../shared/domain/entities/promotion_campaign.dart';
import '../../../../../shared/presentation/providers/pickup_settings_provider.dart';
import '../../../../../shared/presentation/providers/promotion_providers.dart';
import 'recommended_products_section.dart';

class FirstOrderEmpty extends ConsumerWidget {
  const FirstOrderEmpty({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delivery = ref.watch(activePromotionCampaignsProvider);
    final pickup =
        ref.watch(pickupSettingsProvider).valueOrNull?.activeCampaigns ??
            const <PromotionCampaign>[];
    final byId = <String, PromotionCampaign>{
      for (final campaign in [...delivery, ...pickup])
        if (_isVisible(campaign)) campaign.id: campaign,
    };
    final campaigns = byId.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final featured =
        campaigns.where((campaign) => campaign.firstOrderOnly).toList();
    final others =
        campaigns.where((campaign) => !campaign.firstOrderOnly).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF4D7A),
                    AppColors.primary,
                    AppColors.primaryDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    color: AppColors.white,
                    size: 32,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    LocaleKeys.ordersEmptyTitle.tr(),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    LocaleKeys.ordersEmptyHint.tr(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.white.withValues(alpha: 0.94),
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFE14A),
                      foregroundColor: const Color(0xFF5A3B00),
                    ),
                    onPressed: () => context.go(RoutePaths.customerHome),
                    icon: const Icon(Icons.restaurant_menu),
                    label: Text(LocaleKeys.ordersEmptyCta.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (featured.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionTitle(LocaleKeys.ordersFirstCampaign.tr()),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverList.separated(
              itemCount: featured.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _CampaignOfferCard(
                campaign: featured[index],
                highlighted: true,
              ),
            ),
          ),
        ],
        if (others.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionTitle(LocaleKeys.ordersOtherCampaigns.tr()),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            sliver: SliverList.separated(
              itemCount: others.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) => _CampaignOfferCard(
                campaign: others[index],
                highlighted: false,
              ),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: RecommendedProductsSection()),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
      ],
    );
  }

  bool _isVisible(PromotionCampaign campaign) {
    return campaign.isActive &&
        campaign.hasStarted &&
        !campaign.isExpired &&
        campaign.hasUsesLeft;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _CampaignOfferCard extends StatelessWidget {
  const _CampaignOfferCard({
    required this.campaign,
    required this.highlighted,
  });

  final PromotionCampaign campaign;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final description = campaign.description.trim();
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(RoutePaths.customerHome),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted ? const Color(0xFFFFE14A) : AppColors.divider,
              width: highlighted ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (highlighted)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFE14A),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    LocaleKeys.ordersFirstCampaign.tr(),
                    style: const TextStyle(
                      color: Color(0xFF5A3B00),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              Text(
                campaign.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                _offerLabel(campaign),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                ),
              ],
              if (campaign.hasCode) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  campaign.normalizedCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _plainAmount(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }

  String _offerLabel(PromotionCampaign campaign) {
    final type = campaign.type.localeKey.tr();
    return switch (campaign.type) {
      PromotionType.percentDiscount =>
        '%${_plainAmount(campaign.value)} · $type',
      PromotionType.fixedDiscount =>
        '${FormatUtils.currency(campaign.value)} · $type',
      _ => type,
    };
  }
}
