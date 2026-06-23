import 'package:easy_localization/easy_localization.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';



import '../../../../../core/localization/locale_keys.dart';

import '../../../../../core/services/payment_service.dart';

import '../../../../../core/theme/app_colors.dart';

import '../../../../../core/theme/app_spacing.dart';

import '../../../../../core/utils/format_utils.dart';

import '../../../../../core/widgets/app_button.dart';

import '../../../../../shared/domain/entities/order.dart';

import '../../../../../shared/domain/entities/saved_card.dart';



class PaymentPage extends StatefulWidget {

  const PaymentPage({

    super.key,

    required this.amount,

    this.savedCard,

  });



  final double amount;

  final SavedCard? savedCard;



  @override

  State<PaymentPage> createState() => _PaymentPageState();

}



class _PaymentPageState extends State<PaymentPage> {

  final _cardController = TextEditingController();

  final _expiryController = TextEditingController();

  final _cvvController = TextEditingController();

  final _holderController = TextEditingController();

  var _isLoading = false;



  bool get _isSavedCardMode => widget.savedCard != null;



  @override

  void initState() {

    super.initState();

    final card = widget.savedCard;

    if (card != null) {

      _holderController.text = card.holderName;

      _expiryController.text = card.expiry;

      _cardController.text = '**** **** **** ${card.lastFour}';

    }

  }



  @override

  void dispose() {

    _cardController.dispose();

    _expiryController.dispose();

    _cvvController.dispose();

    _holderController.dispose();

    super.dispose();

  }



  Future<void> _pay() async {

    setState(() => _isLoading = true);

    try {

      final PaymentResult result;

      if (_isSavedCardMode) {

        result = await PaymentService.processSavedCardPayment(

          amount: widget.amount,

          cvv: _cvvController.text,

          lastFour: widget.savedCard!.lastFour,

        );

      } else {

        result = await PaymentService.processCardPayment(

          amount: widget.amount,

          cardNumber: _cardController.text,

          expiry: _expiryController.text,

          cvv: _cvvController.text,

          cardHolder: _holderController.text,

        );

      }

      if (!mounted) return;

      Navigator.pop(context, result);

    } on PaymentException catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(e.messageKey.tr())),

      );

    } finally {

      if (mounted) setState(() => _isLoading = false);

    }

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: Text(LocaleKeys.paymentTitle.tr())),

      body: SingleChildScrollView(

        padding: const EdgeInsets.all(AppSpacing.lg),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            Container(

              padding: const EdgeInsets.all(AppSpacing.lg),

              decoration: BoxDecoration(

                gradient: LinearGradient(

                  colors: [AppColors.primary, AppColors.primaryDark],

                ),

                borderRadius: BorderRadius.circular(16),

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    _isSavedCardMode

                        ? LocaleKeys.paymentSavedCardHint.tr()

                        : LocaleKeys.paymentSecure.tr(),

                    style: Theme.of(context).textTheme.bodySmall?.copyWith(

                          color: AppColors.white.withValues(alpha: 0.85),

                        ),

                  ),

                  const SizedBox(height: AppSpacing.sm),

                  Text(

                    FormatUtils.currency(widget.amount),

                    style: Theme.of(context).textTheme.displayLarge?.copyWith(

                          color: AppColors.white,

                        ),

                  ),

                ],

              ),

            ),

            const SizedBox(height: AppSpacing.md),

            if (!_isSavedCardMode)

              Text(

                LocaleKeys.paymentDemoHint.tr(),

                style: Theme.of(context).textTheme.bodySmall?.copyWith(

                      color: AppColors.warning,

                    ),

              ),

            if (!_isSavedCardMode) const SizedBox(height: AppSpacing.lg),

            if (!_isSavedCardMode)

              TextField(

                controller: _holderController,

                textCapitalization: TextCapitalization.words,

                decoration: InputDecoration(

                  labelText: LocaleKeys.paymentCardHolder.tr(),

                  border: OutlineInputBorder(

                    borderRadius: BorderRadius.circular(12),

                  ),

                ),

              ),

            if (!_isSavedCardMode) const SizedBox(height: AppSpacing.sm),

            TextField(

              controller: _cardController,

              readOnly: _isSavedCardMode,

              keyboardType: TextInputType.number,

              inputFormatters: _isSavedCardMode

                  ? null

                  : [

                      FilteringTextInputFormatter.digitsOnly,

                      LengthLimitingTextInputFormatter(16),

                    ],

              decoration: InputDecoration(

                labelText: _isSavedCardMode

                    ? LocaleKeys.paymentUseSavedCard.tr()

                    : LocaleKeys.paymentCardNumber.tr(),

                hintText: _isSavedCardMode ? null : '4242 4242 4242 4242',

                prefixIcon: const Icon(Icons.credit_card),

                border: OutlineInputBorder(

                  borderRadius: BorderRadius.circular(12),

                ),

              ),

            ),

            const SizedBox(height: AppSpacing.sm),

            Row(

              children: [

                if (!_isSavedCardMode)

                  Expanded(

                    child: TextField(

                      controller: _expiryController,

                      keyboardType: TextInputType.datetime,

                      decoration: InputDecoration(

                        labelText: LocaleKeys.paymentExpiry.tr(),

                        hintText: '12/28',

                        border: OutlineInputBorder(

                          borderRadius: BorderRadius.circular(12),

                        ),

                      ),

                    ),

                  ),

                if (!_isSavedCardMode)

                  const SizedBox(width: AppSpacing.sm),

                Expanded(

                  child: TextField(

                    controller: _cvvController,

                    keyboardType: TextInputType.number,

                    obscureText: true,

                    inputFormatters: [

                      FilteringTextInputFormatter.digitsOnly,

                      LengthLimitingTextInputFormatter(4),

                    ],

                    decoration: InputDecoration(

                      labelText: LocaleKeys.paymentCvv.tr(),

                      border: OutlineInputBorder(

                        borderRadius: BorderRadius.circular(12),

                      ),

                    ),

                  ),

                ),

              ],

            ),

            const SizedBox(height: AppSpacing.xl),

            AppButton(

              labelKey: LocaleKeys.paymentPayNow,

              isLoading: _isLoading,

              onPressed: _pay,

            ),

          ],

        ),

      ),

    );

  }

}

