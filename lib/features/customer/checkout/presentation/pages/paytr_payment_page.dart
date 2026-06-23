import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/format_utils.dart';
import '../../../../../shared/data/models/payment_models.dart';
import '../../../../../shared/data/repositories/payment_repository.dart';
import '../../../../../shared/domain/entities/order.dart';
import '../../../../../shared/presentation/providers/paytr_settings_provider.dart';
import '../../../../../shared/presentation/providers/repository_providers.dart';

class PaytrPaymentPage extends ConsumerStatefulWidget {
  const PaytrPaymentPage({
    super.key,
    required this.amount,
    required this.email,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.basketSummary,
    required this.items,
  });

  final double amount;
  final String email;
  final String customerName;
  final String phone;
  final String address;
  final String basketSummary;
  final List<CartItem> items;

  @override
  ConsumerState<PaytrPaymentPage> createState() => _PaytrPaymentPageState();
}

class _PaytrPaymentPageState extends ConsumerState<PaytrPaymentPage> {
  WebViewController? _controller;
  var _loading = true;
  var _errorKey = '';
  late final String _merchantOid;

  @override
  void initState() {
    super.initState();
    _merchantOid = buildPaytrMerchantOid();
    _initPayment();
  }

  Future<void> _initPayment() async {
    try {
      final settings = ref.read(paytrSettingsProvider).valueOrNull;
      final init = await ref.read(paymentRepositoryProvider).initPaytr(
            PaytrInitRequest(
              merchantOid: _merchantOid,
              amount: widget.amount,
              email: widget.email,
              customerName: widget.customerName,
              phone: widget.phone,
              address: widget.address,
              basketSummary: widget.basketSummary,
              items: widget.items,
            ),
            settings: settings,
            items: widget.items,
          );

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              if (mounted) setState(() => _loading = false);
            },
            onNavigationRequest: _handleNavigation,
          ),
        );

      if (AppConfig.useMockApi) {
        controller.addJavaScriptChannel(
          'PayTRBridge',
          onMessageReceived: (message) => _handleBridgeMessage(message.message),
        );
        await controller.loadFlutterAsset('assets/paytr/demo_checkout.html');
      } else {
        await controller.loadRequest(Uri.parse(init.iframeUrl));
      }

      if (!mounted) return;
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorKey = LocaleKeys.paymentPaytrInitFailed;
        _loading = false;
      });
    }
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final url = request.url;
    final settings = ref.read(paytrSettingsProvider).valueOrNull;
    final successUrl = settings?.successRedirectUrl.trim().isNotEmpty == true
        ? settings!.successRedirectUrl.trim()
        : AppConfig.paytrSuccessUrl;
    final failUrl = settings?.failRedirectUrl.trim().isNotEmpty == true
        ? settings!.failRedirectUrl.trim()
        : AppConfig.paytrFailUrl;
    if (url.startsWith(successUrl) || url.contains('payment/success')) {
      _completePayment(success: true);
      return NavigationDecision.prevent;
    }
    if (url.startsWith(failUrl) || url.contains('payment/fail')) {
      _completePayment(success: false);
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _handleBridgeMessage(String message) {
    _completePayment(success: message == 'success');
  }

  Future<void> _completePayment({required bool success}) async {
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.paymentPaytrFailed.tr())),
        );
        Navigator.pop(context);
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final settings = ref.read(paytrSettingsProvider).valueOrNull;
      final result = await ref.read(paymentRepositoryProvider).verifyPaytr(
            _merchantOid,
            widget.amount,
            settings: settings,
          );
      if (!mounted) return;
      Navigator.pop(context, result);
    } on PaymentException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.messageKey.tr())),
      );
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.paymentPaytrFailed.tr())),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.paymentPaytrTitle.tr()),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(Icons.lock, color: AppColors.primary, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${LocaleKeys.paymentSecure.tr()} · ${FormatUtils.currency(widget.amount)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                        ),
                  ),
                ),
              ],
            ),
          ),
          if (AppConfig.useMockApi)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                LocaleKeys.paymentPaytrDemoHint.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: _errorKey.isNotEmpty
                ? Center(child: Text(_errorKey.tr()))
                : Stack(
                    children: [
                      if (_controller != null)
                        WebViewWidget(controller: _controller!),
                      if (_loading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
