import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../core/utils/promotion_utils.dart';
import '../../../../../core/widgets/product_thumbnail.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/promotion_campaign.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../../shared/presentation/providers/pickup_settings_provider.dart';
import '../../../../../shared/presentation/providers/waiter_mode_settings_provider.dart';
import '../../../checkout/presentation/providers/coupon_provider.dart';
import '../../../pickup/presentation/providers/fulfillment_mode_provider.dart';
import '../providers/branch_provider.dart';

/// Anasayfada yöneticinin aktif kampanyaları ve bu kampanyalara giren ürünler.
class HomeCampaignProductsSection extends ConsumerWidget {
  const HomeCampaignProductsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFirstOrder = ref.watch(customerIsFirstOrderProvider);
    final campaigns = ref
        .watch(checkoutCampaignsProvider)
        .where(
          (campaign) => PromotionUtils.canOfferInPicker(
            campaign,
            isFirstOrder: isFirstOrder,
          ),
        )
        .toList();
    if (campaigns.isEmpty) return const SizedBox.shrink();

    final catalog = ref.watch(productsProvider).value ?? const <Product>[];
    final sahandaEnabled =
        ref.watch(waiterModeSettingsProvider).valueOrNull?.customerSahandaEnabled ??
            true;
    final pickupActive = ref.watch(customerPickupActiveProvider);
    final pickupSettings = ref.watch(pickupSettingsProvider).valueOrNull;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                LocaleKeys.customerCampaignProducts.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final campaign in campaigns) ...[
            _CampaignProductsCard(
              campaign: campaign,
              products: PromotionUtils.productsForCampaign(
                campaign,
                catalog,
                sahandaEnabled: sahandaEnabled,
              ),
              pickupActive: pickupActive,
              priceFor: (product) => customerUnitPrice(
                product: product,
                pickupActive: pickupActive,
                settings: pickupSettings,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _CampaignProductsCard extends StatelessWidget {
  const _CampaignProductsCard({
    required this.campaign,
    required this.products,
    required this.pickupActive,
    required this.priceFor,
  });

  final PromotionCampaign campaign;
  final List<Product> products;
  final bool pickupActive;
  final double Function(Product product) priceFor;

  @override
  Widget build(BuildContext context) {
    final description = campaign.description.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A1020).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (campaign.firstOrderOnly) _OfferChip(LocaleKeys.ordersFirstCampaign.tr()),
              _OfferChip(_offerLabel(campaign)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            campaign.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
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
          if (products.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final product = products[index];
                  return _CampaignProductTile(
                    product: product,
                    price: priceFor(product),
                    showMenuPrice: pickupActive &&
                        priceFor(product) + 0.009 < product.price,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _offerLabel(PromotionCampaign campaign) {
    final type = campaign.type.localeKey.tr();
    return switch (campaign.type) {
      PromotionType.percentDiscount => '%${_plainAmount(campaign.value)} · $type',
      PromotionType.fixedDiscount =>
        '${FormatUtils.currency(campaign.value)} · $type',
      PromotionType.buyXGetY =>
        '${campaign.buyQuantity} al ${campaign.freeQuantity} bedava · $type',
      _ => type,
    };
  }

  String _plainAmount(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2);
  }
}

class _OfferChip extends StatelessWidget {
  const _OfferChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE14A),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF5A3B00),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CampaignProductTile extends StatelessWidget {
  const _CampaignProductTile({
    required this.product,
    required this.price,
    required this.showMenuPrice,
  });

  final Product product;
  final double price;
  final bool showMenuPrice;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: Material(
        color: const Color(0xFFF7F2F4),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(RoutePaths.customerProduct(product.id)),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ProductThumbnail(
                    category: product.category,
                    imageColorValue: product.imageColorValue,
                    imageUrl: product.imageUrl,
                    width: 72,
                    height: 72,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  localizedOrRaw(product.nameKey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  FormatUtils.currency(price),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                if (showMenuPrice)
                  Text(
                    FormatUtils.currency(product.price),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
