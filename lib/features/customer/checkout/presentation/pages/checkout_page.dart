import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/analytics/meta_analytics.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../../shared/data/repositories/payment_repository.dart';
import '../../../../../shared/domain/entities/delivery_address.dart';
import '../../../../../shared/domain/entities/branch.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/domain/entities/promotion_campaign.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../../shared/presentation/providers/promotion_providers.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../customer/cart/presentation/providers/cart_provider.dart';
import '../../../../customer/home/presentation/providers/branch_provider.dart';
import '../../../../customer/profile/presentation/providers/address_provider.dart';
import '../../../../customer/profile/presentation/widgets/address_editor_sheet.dart';
import '../../../../customer/cart/presentation/providers/delivery_providers.dart';
import '../../../../../shared/presentation/providers/delivery_settings_provider.dart';
import '../../../../../shared/presentation/providers/checkout_paytr_providers.dart';
import '../../../../../shared/presentation/providers/paytr_settings_provider.dart';
import '../models/paytr_checkout_args.dart';
import '../../../cart/presentation/widgets/campaign_picker_sheet.dart';
import '../providers/coupon_provider.dart';

class CheckoutPage extends ConsumerStatefulWidget {
  const CheckoutPage({super.key});

  @override
  ConsumerState<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends ConsumerState<CheckoutPage> {
  PaymentMethod _paymentMethod = PaymentMethod.cashOnDelivery;
  bool _deliveryNow = true;
  DateTime? _scheduledAt;
  final _noteController = TextEditingController();
  var _isPlacingOrder = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _consumeCampaignUse() async {
    final selected = ref.read(appliedCheckoutDiscountProvider);
    final campaignId = selected?.campaignId;
    if (campaignId == null) return;
    final campaigns = ref.read(activePromotionCampaignsProvider);
    PromotionCampaign? campaign;
    for (final item in campaigns) {
      if (item.id == campaignId) {
        campaign = item;
        break;
      }
    }
    final remaining = campaign?.remainingUses;
    if (campaign == null || remaining == null || remaining <= 0) return;
    await savePromotionCampaign(
      ref,
      campaign.copyWith(remainingUses: remaining - 1),
    );
  }

  String _addressTitle(DeliveryAddress address) {
    return address.title.startsWith('address_')
        ? address.title.tr()
        : address.title;
  }

  Future<void> _pickScheduledDateTime(Branch branch) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 7)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        now.add(const Duration(hours: 1)),
      ),
      helpText: LocaleKeys.checkoutScheduledPickDate.tr(),
    );
    if (time == null || !mounted) return;

    final scheduled = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!scheduled.isAfter(now.add(const Duration(minutes: 30)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.checkoutScheduledTooSoon.tr())),
      );
      return;
    }

    if (!branch.isOpenAt(scheduled)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocaleKeys.checkoutScheduledInvalidHours.tr(
              namedArgs: {'hours': branch.hoursLabel},
            ),
          ),
        ),
      );
      return;
    }

    setState(() => _scheduledAt = scheduled);
  }

  bool _isScheduledDeliveryValid(Branch branch) {
    if (_deliveryNow) return true;
    final scheduled = _scheduledAt;
    if (scheduled == null) return false;
    return branch.isValidScheduledDelivery(scheduled);
  }

  bool _canPlaceOrder({
    required Branch? branch,
    required bool outOfZone,
  }) {
    if (branch == null || outOfZone) return false;
    if (_deliveryNow) return branch.isOpenNow;
    return _isScheduledDeliveryValid(branch);
  }

  Future<void> _addOrEditCheckoutAddress({DeliveryAddress? existing}) async {
    final created = await showAddressEditorSheet(
      context: context,
      ref: ref,
      existing: existing,
      defaultSaveAsDefault: existing == null,
      saveHint: LocaleKeys.checkoutAddressSaveHint.tr(),
    );
    if (created == null || !mounted) return;
    ref.read(selectedCheckoutAddressProvider.notifier).state = created;
  }

  void _showAddressPicker(List<DeliveryAddress> addresses) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final selectedId = ref.read(selectedCheckoutAddressProvider)?.id;
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(title: Text(LocaleKeys.checkoutSelectAddress.tr())),
                ...addresses.map(
                  (address) => ListTile(
                    leading: Icon(
                      address.isDefault
                          ? Icons.home
                          : Icons.location_on_outlined,
                      color: address.isDefault ? AppColors.primary : null,
                    ),
                    title: Text(_addressTitle(address)),
                    subtitle: Text(address.fullAddress),
                    trailing: address.id == selectedId ||
                            (selectedId == null && address.isDefault)
                        ? const Icon(Icons.check, color: AppColors.primary)
                        : null,
                    onTap: () {
                      ref
                          .read(selectedCheckoutAddressProvider.notifier)
                          .state = address;
                      Navigator.pop(sheetContext);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: Text(LocaleKeys.checkoutAddAddress.tr()),
                  subtitle: Text(LocaleKeys.checkoutAddressSaveHint.tr()),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _addOrEditCheckoutAddress();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _placeOrder() async {
    if (_isPlacingOrder) return;

    final auth = ref.read(authProvider);
    if (auth == null) return;

    final cart = ref.read(cartProvider);
    if (cart.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.customerCartEmpty.tr())),
        );
      }
      return;
    }

    final branch = ref.read(branchProvider).value;
    if (branch == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.checkoutBranchMissing.tr())),
        );
      }
      return;
    }

    if (_deliveryNow) {
      if (!branch.isOpenNow) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LocaleKeys.branchClosedMessage.tr())),
          );
        }
        return;
      }
    } else {
      if (_scheduledAt == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LocaleKeys.checkoutScheduledRequired.tr())),
          );
        }
        return;
      }
      if (!branch.isValidScheduledDelivery(_scheduledAt!)) {
        if (mounted) {
          final tooSoon =
              !_scheduledAt!.isAfter(DateTime.now().add(const Duration(minutes: 30)));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                tooSoon
                    ? LocaleKeys.checkoutScheduledTooSoon.tr()
                    : LocaleKeys.checkoutScheduledInvalidHours.tr(
                        namedArgs: {'hours': branch.hoursLabel},
                      ),
              ),
            ),
          );
        }
        return;
      }
    }

    final addresses = ref.read(addressProvider).value ?? [];
    if (addresses.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.checkoutSelectAddress.tr())),
        );
      }
      return;
    }

    final selectedAddress = ref.read(selectedCheckoutAddressProvider) ??
        addresses.firstWhere(
          (a) => a.isDefault,
          orElse: () => addresses.first,
        );

    if (selectedAddress.latitude != null &&
        selectedAddress.longitude != null &&
        !ref.read(branchProvider.notifier).isAddressDeliverable(
              branch,
              selectedAddress.latitude,
              selectedAddress.longitude,
            )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.deliveryOutOfZone.tr())),
        );
      }
      return;
    }

    final total = ref.read(checkoutPayableTotalProvider);
    final discount = ref.read(checkoutDiscountProvider);
    final discountCode = ref.read(checkoutDiscountCodeProvider);
    final deliveryFee = ref.read(deliveryFeeProvider);
    final etaMinutes = ref.read(checkoutEtaMinutesProvider);
    final cartBranchId = ref.read(cartBranchIdProvider);

    if (cartBranchId != null && cartBranchId != branch.id) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.cartBranchMismatch.tr())),
        );
      }
      return;
    }

    String? paymentTransactionId;
    if (_paymentMethod == PaymentMethod.onlineCard) {
      final paytrEnabled = ref.read(paytrEnabledProvider);
      if (!paytrEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(LocaleKeys.paymentPaytrInitFailed.tr())),
          );
        }
        return;
      }

      final email = auth.email?.isNotEmpty == true
          ? auth.email!
          : '${auth.phone}@tostusahane.com';
      final paymentResult = await context.push<PaymentResult>(
        RoutePaths.customerPaytrPayment,
        extra: PaytrCheckoutArgs(
          amount: total,
          email: email,
          customerName: auth.user.name.tr(),
          phone: auth.phone,
          address: selectedAddress.fullAddress,
          basketSummary: buildPaytrBasketSummary(cart),
          items: cart,
        ),
      );
      if (paymentResult == null || !mounted) return;
      paymentTransactionId = paymentResult.transactionId;
    }

    var orderNote = _noteController.text.trim();
    if (!_deliveryNow && _scheduledAt != null) {
      final scheduled = DateFormat('dd.MM.yyyy HH:mm').format(_scheduledAt!);
      final scheduledNote =
          LocaleKeys.checkoutScheduledLabel.tr(namedArgs: {'datetime': scheduled});
      orderNote = orderNote.isEmpty
          ? scheduledNote
          : '$scheduledNote\n$orderNote';
    }

    setState(() => _isPlacingOrder = true);
    try {
      final order = await ref.read(ordersProvider.notifier).placeOrder(
            items: cart,
            totalAmount: total,
            customerId: auth.user.id,
            customerName: auth.user.name.tr(),
            branchId: branch.id,
            address: selectedAddress.fullAddress,
            paymentMethod: _paymentMethod,
            orderNote: orderNote.isEmpty ? null : orderNote,
            deliveryNow: _deliveryNow,
            scheduledAt: _deliveryNow ? null : _scheduledAt,
            deliveryLatitude: selectedAddress.latitude,
            deliveryLongitude: selectedAddress.longitude,
            customerPhone: auth.phone,
            deliveryDirections: selectedAddress.note,
            paymentTransactionId: paymentTransactionId,
            couponCode: discountCode,
            discountAmount: discount,
            deliveryFeeAmount: deliveryFee,
            estimatedDeliveryMinutes: etaMinutes,
          );

      await MetaAnalytics.logPurchase(order);
      await _consumeCampaignUse();

      ref.read(cartProvider.notifier).clear();
      ref.read(couponNotifierProvider).clear();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.success, size: 48),
          title: Text(LocaleKeys.checkoutSuccess.tr()),
          content: Text(
            LocaleKeys.orderNumber.tr(
              namedArgs: {'number': '${order.orderNumber}'},
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(LocaleKeys.orderTrack.tr()),
            ),
          ],
        ),
      );

      if (!mounted) return;
      context.go(RoutePaths.customerOrderTrack(order.id));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.checkoutFailed.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = ref.watch(checkoutPayableTotalProvider);
    final vatAmount = ref.watch(checkoutVatAmountProvider);
    final showVatLine = ref.watch(checkoutShowsVatLineProvider);
    final discount = ref.watch(checkoutDiscountProvider);
    final discountLabel = ref.watch(checkoutDiscountLabelProvider);
    final discountCode = ref.watch(checkoutDiscountCodeProvider);
    final freeDeliveryMinOrder = ref.watch(effectiveFreeDeliveryMinOrderProvider);
    final deliveryFee = ref.watch(deliveryFeeProvider);
    final etaMinutes = ref.watch(checkoutEtaMinutesProvider);
    final paytrEnabled = ref.watch(paytrEnabledProvider);
    final paytrSettings = ref.watch(paytrSettingsProvider).valueOrNull;
    final addressesAsync = ref.watch(addressProvider);
    final selectedAddress = ref.watch(selectedCheckoutAddressProvider);
    final branch = ref.watch(branchProvider).value;
    final canSubmitOrder = addressesAsync.maybeWhen(
      data: (addresses) {
        if (addresses.isEmpty) return false;
        final address = selectedAddress ??
            addresses.firstWhere(
              (a) => a.isDefault,
              orElse: () => addresses.first,
            );
        final outOfZone = branch != null &&
            address.latitude != null &&
            address.longitude != null &&
            !ref.read(branchProvider.notifier).isAddressDeliverable(
                  branch,
                  address.latitude,
                  address.longitude,
                );
        return _canPlaceOrder(branch: branch, outOfZone: outOfZone);
      },
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.checkoutTitle.tr())),
      body: addressesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(LocaleKeys.commonError.tr()),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton(
                  onPressed: () => ref.invalidate(addressProvider),
                  child: Text(LocaleKeys.commonRetry.tr()),
                ),
              ],
            ),
          ),
        ),
        data: (addresses) {
          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_location_alt_outlined, size: 48),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      LocaleKeys.checkoutAddressRequiredHint.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      LocaleKeys.checkoutAddressSaveHint.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton(
                      labelKey: LocaleKeys.checkoutAddAddress,
                      onPressed: () => _addOrEditCheckoutAddress(),
                    ),
                  ],
                ),
              ),
            );
          }

          final address = selectedAddress ??
              addresses.firstWhere(
                (a) => a.isDefault,
                orElse: () => addresses.first,
              );

          final outOfZone = branch != null &&
              address.latitude != null &&
              address.longitude != null &&
              !ref.read(branchProvider.notifier).isAddressDeliverable(
                    branch,
                    address.latitude,
                    address.longitude,
                  );
          final branchClosedNow = branch != null && !branch.isOpenNow;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (branchClosedNow && _deliveryNow)
                  MaterialBanner(
                    backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                    content: Text(LocaleKeys.branchClosedMessage.tr()),
                    leading: const Icon(Icons.schedule, color: AppColors.warning),
                    actions: const [SizedBox.shrink()],
                  ),
                if (branchClosedNow && !_deliveryNow)
                  MaterialBanner(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    content: Text(
                      LocaleKeys.checkoutScheduledBranchClosedHint.tr(
                        namedArgs: {'hours': branch.hoursLabel},
                      ),
                    ),
                    leading: const Icon(Icons.event, color: AppColors.primary),
                    actions: const [SizedBox.shrink()],
                  ),
                Text(
                  LocaleKeys.checkoutAddress.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(_addressTitle(address)),
                  subtitle: Text(address.fullAddress),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => _showAddressPicker(addresses),
                        child: Text(LocaleKeys.checkoutSelectAddress.tr()),
                      ),
                      IconButton(
                        tooltip: LocaleKeys.checkoutAddAddress.tr(),
                        onPressed: () => _addOrEditCheckoutAddress(),
                        icon: const Icon(Icons.add_location_alt_outlined),
                      ),
                    ],
                  ),
                ),
                if (outOfZone)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: MaterialBanner(
                      backgroundColor: AppColors.error.withValues(alpha: 0.08),
                      content: Text(LocaleKeys.deliveryOutOfZone.tr()),
                      leading: const Icon(Icons.warning_amber, color: AppColors.error),
                      actions: const [SizedBox.shrink()],
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  LocaleKeys.checkoutDeliveryTime.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                RadioListTile<bool>(
                  title: Text(LocaleKeys.checkoutDeliveryNow.tr()),
                  value: true,
                  groupValue: _deliveryNow,
                  onChanged: (v) => setState(() {
                    _deliveryNow = v!;
                    _scheduledAt = null;
                  }),
                ),
                RadioListTile<bool>(
                  title: Text(LocaleKeys.checkoutDeliveryScheduled.tr()),
                  value: false,
                  groupValue: _deliveryNow,
                  onChanged: (v) => setState(() => _deliveryNow = v!),
                ),
                if (!_deliveryNow)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md),
                    child: OutlinedButton.icon(
                      onPressed: branch == null
                          ? null
                          : () => _pickScheduledDateTime(branch),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _scheduledAt == null
                            ? LocaleKeys.checkoutScheduledPickDate.tr()
                            : LocaleKeys.checkoutScheduledLabel.tr(
                                namedArgs: {
                                  'datetime': DateFormat('dd.MM.yyyy HH:mm')
                                      .format(_scheduledAt!),
                                },
                              ),
                      ),
                    ),
                  ),
                if (!_deliveryNow && branch != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      top: AppSpacing.xs,
                    ),
                    child: Text(
                      branch.hoursLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  LocaleKeys.checkoutPaymentMethod.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (paytrEnabled)
                  RadioListTile<PaymentMethod>(
                    title: Text(LocaleKeys.checkoutPaymentCard.tr()),
                    value: PaymentMethod.onlineCard,
                    groupValue: _paymentMethod,
                    onChanged: (v) => setState(() => _paymentMethod = v!),
                  ),
                RadioListTile<PaymentMethod>(
                  title: Text(LocaleKeys.checkoutPaymentCash.tr()),
                  value: PaymentMethod.cashOnDelivery,
                  groupValue: _paymentMethod,
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
                RadioListTile<PaymentMethod>(
                  title: Text(LocaleKeys.checkoutPaymentCardDoor.tr()),
                  value: PaymentMethod.cardOnDelivery,
                  groupValue: _paymentMethod,
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                ),
                if (_paymentMethod == PaymentMethod.onlineCard && paytrEnabled)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.md),
                    child: Text(
                      LocaleKeys.checkoutPaytrNote.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                const CampaignPickerTile(),
                if (discount > 0 && discountLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      LocaleKeys.checkoutCouponDiscount.tr(
                        namedArgs: {
                          'code': discountCode ?? discountLabel!,
                          'amount': FormatUtils.currency(discount),
                        },
                      ),
                      style: const TextStyle(color: AppColors.success),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  LocaleKeys.checkoutEtaLabel.tr(
                    namedArgs: {'minutes': '$etaMinutes'},
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.primary,
                      ),
                ),
                Text(
                  LocaleKeys.checkoutDeliveryFeeLine.tr(
                    namedArgs: {
                      'fee': deliveryFee <= 0
                          ? LocaleKeys.customerDeliveryFree.tr()
                          : FormatUtils.currency(deliveryFee),
                    },
                  ),
                ),
                if (deliveryFee <= 0)
                  Text(
                    LocaleKeys.customerDeliveryFreeHint.tr(
                      namedArgs: {
                        'amount': freeDeliveryMinOrder.toStringAsFixed(0),
                      },
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                        ),
                  ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _noteController,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.checkoutOrderNote.tr(),
                    hintText: LocaleKeys.checkoutOrderNoteHint.tr(),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (showVatLine)
                  Text(
                    LocaleKeys.checkoutVatLine.tr(
                      namedArgs: {
                        'rate':
                            '${paytrSettings?.vatRatePercent.toStringAsFixed(0) ?? '0'}',
                        'amount': FormatUtils.currency(vatAmount),
                        'mode': paytrSettings?.vatIncluded == true
                            ? LocaleKeys.adminPaytrVatIncluded.tr()
                            : LocaleKeys.adminPaytrVatExcluded.tr(),
                      },
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                if (showVatLine) const SizedBox(height: AppSpacing.sm),
                Text(
                  FormatUtils.currency(total),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: AppButton(
            labelKey: LocaleKeys.checkoutButtonText,
            isLoading: _isPlacingOrder,
            onPressed: canSubmitOrder && !_isPlacingOrder ? _placeOrder : null,
          ),
        ),
      ),
    );
  }
}
