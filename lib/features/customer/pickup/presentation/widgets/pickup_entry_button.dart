import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../shared/presentation/providers/pickup_settings_provider.dart';
import '../../../cart/presentation/providers/cart_provider.dart';
import '../../../checkout/presentation/providers/coupon_provider.dart';
import '../providers/fulfillment_mode_provider.dart';

class PickupEntryButton extends ConsumerWidget {
  const PickupEntryButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(pickupSettingsProvider).valueOrNull;
    if (settings == null || !settings.enabled) return const SizedBox.shrink();

    final active = ref.watch(customerPickupActiveProvider);
    final badge = settings.badgeText.trim().isEmpty
        ? LocaleKeys.pickupEntryBadge.tr()
        : settings.badgeText;
    final headline = settings.headline.trim().isEmpty
        ? LocaleKeys.navPickup.tr()
        : settings.headline;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: DecoratedBox(
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
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => openPickupMenu(context, ref),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.white.withValues(alpha: 0.45),
                          ),
                        ),
                        child: const Icon(
                          Icons.shopping_bag_rounded,
                          color: AppColors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE14A),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badge.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFF5A3B00),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              headline,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w900,
                                    height: 1.05,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const _PickupCampaignNudge(),
                  if (!active && settings.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      settings.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.white.withValues(alpha: 0.92),
                          ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _PickupPerk(
                        icon: Icons.schedule_rounded,
                        label: LocaleKeys.pickupReadyIn.tr(
                          namedArgs: {'minutes': '${settings.readyMinutes}'},
                        ),
                      ),
                      _PickupPerk(
                        icon: Icons.delivery_dining_outlined,
                        label: LocaleKeys.pickupPerkNoFee.tr(),
                      ),
                      _PickupPerk(
                        icon: Icons.storefront_rounded,
                        label: LocaleKeys.pickupPerkPayAtStore.tr(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PickupCampaignNudge extends StatefulWidget {
  const _PickupCampaignNudge();

  @override
  State<_PickupCampaignNudge> createState() => _PickupCampaignNudgeState();
}

class _PickupCampaignNudgeState extends State<_PickupCampaignNudge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_controller.value);
            return Transform.scale(
              scale: 0.98 + (0.045 * t),
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(
                    const Color(0xFFFFE14A),
                    const Color(0xFFFFF6C2),
                    t,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFE14A)
                          .withValues(alpha: 0.28 + (0.45 * t)),
                      blurRadius: 6 + (10 * t),
                      spreadRadius: t,
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_offer_rounded,
                  size: 15,
                  color: Color(0xFF5A3B00),
                ),
                const SizedBox(width: 5),
                Text(
                  LocaleKeys.pickupModeActive.tr(),
                  softWrap: false,
                  style: const TextStyle(
                    color: Color(0xFF5A3B00),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
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

class _PickupPerk extends StatelessWidget {
  const _PickupPerk({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> openPickupMenu(BuildContext context, WidgetRef ref) async {
  final switched = await _switchFulfillment(
    context,
    ref,
    CustomerFulfillment.pickup,
  );
  if (!switched || !context.mounted) return;
  context.push(RoutePaths.customerPickup);
}

Future<bool> switchToDelivery(BuildContext context, WidgetRef ref) {
  return _switchFulfillment(context, ref, CustomerFulfillment.delivery);
}

/// Ana sayfa, siparişler veya profile dönünce Gel Al kapanır.
/// Dolu sepet teslimat fiyatlarıyla karışmasın diye temizlenir.
bool leavePickupSection(WidgetRef ref) {
  if (ref.read(fulfillmentModeProvider) != CustomerFulfillment.pickup) {
    return false;
  }
  final hadCart = ref.read(cartProvider).isNotEmpty;
  if (hadCart) {
    ref.read(cartProvider.notifier).clear();
  }
  ref.read(appliedCheckoutDiscountProvider.notifier).state = null;
  ref.read(fulfillmentModeProvider.notifier).set(CustomerFulfillment.delivery);
  return hadCart;
}

Future<bool> _switchFulfillment(
  BuildContext context,
  WidgetRef ref,
  CustomerFulfillment next,
) async {
  final current = ref.read(customerPickupActiveProvider)
      ? CustomerFulfillment.pickup
      : CustomerFulfillment.delivery;
  if (current == next) return true;

  final cart = ref.read(cartProvider);
  if (cart.isNotEmpty) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(LocaleKeys.pickupSwitchTitle.tr()),
        content: Text(LocaleKeys.pickupSwitchMessage.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(LocaleKeys.pickupSwitchConfirm.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    ref.read(cartProvider.notifier).clear();
  }

  ref.read(appliedCheckoutDiscountProvider.notifier).state = null;
  ref.read(fulfillmentModeProvider.notifier).set(next);
  return true;
}
