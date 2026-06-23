class PaytrSettings {
  const PaytrSettings({
    this.enabled = false,
    this.sandboxMode = true,
    this.merchantId = '',
    this.merchantKey = '',
    this.merchantSalt = '',
    this.callbackUrl = '',
    this.successRedirectUrl = '',
    this.failRedirectUrl = '',
    this.vatRatePercent = 10,
    this.vatIncluded = true,
  });

  final bool enabled;
  /// PayTR test_mode: sandbox ödeme ortamı.
  final bool sandboxMode;
  final String merchantId;
  final String merchantKey;
  final String merchantSalt;
  /// Bildirim URL (STEP 2 — sunucu tarafı doğrulama).
  final String callbackUrl;
  final String successRedirectUrl;
  final String failRedirectUrl;
  final double vatRatePercent;
  /// true: menü fiyatları KDV dahil; false: ödeme tutarına KDV eklenir.
  final bool vatIncluded;

  static const defaults = PaytrSettings();

  bool get isConfigured =>
      enabled &&
      merchantId.trim().isNotEmpty &&
      merchantKey.trim().isNotEmpty &&
      merchantSalt.trim().isNotEmpty;

  PaytrSettings copyWith({
    bool? enabled,
    bool? sandboxMode,
    String? merchantId,
    String? merchantKey,
    String? merchantSalt,
    String? callbackUrl,
    String? successRedirectUrl,
    String? failRedirectUrl,
    double? vatRatePercent,
    bool? vatIncluded,
  }) {
    return PaytrSettings(
      enabled: enabled ?? this.enabled,
      sandboxMode: sandboxMode ?? this.sandboxMode,
      merchantId: merchantId ?? this.merchantId,
      merchantKey: merchantKey ?? this.merchantKey,
      merchantSalt: merchantSalt ?? this.merchantSalt,
      callbackUrl: callbackUrl ?? this.callbackUrl,
      successRedirectUrl: successRedirectUrl ?? this.successRedirectUrl,
      failRedirectUrl: failRedirectUrl ?? this.failRedirectUrl,
      vatRatePercent: vatRatePercent ?? this.vatRatePercent,
      vatIncluded: vatIncluded ?? this.vatIncluded,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'sandbox_mode': sandboxMode,
        'merchant_id': merchantId,
        'merchant_key': merchantKey,
        'merchant_salt': merchantSalt,
        'callback_url': callbackUrl,
        'success_redirect_url': successRedirectUrl,
        'fail_redirect_url': failRedirectUrl,
        'vat_rate_percent': vatRatePercent,
        'vat_included': vatIncluded,
      };

  factory PaytrSettings.fromJson(Map<String, dynamic> json) {
    return PaytrSettings(
      enabled: json['enabled'] as bool? ?? false,
      sandboxMode: json['sandbox_mode'] as bool? ?? true,
      merchantId: json['merchant_id'] as String? ?? '',
      merchantKey: json['merchant_key'] as String? ?? '',
      merchantSalt: json['merchant_salt'] as String? ?? '',
      callbackUrl: json['callback_url'] as String? ?? '',
      successRedirectUrl: json['success_redirect_url'] as String? ?? '',
      failRedirectUrl: json['fail_redirect_url'] as String? ?? '',
      vatRatePercent: (json['vat_rate_percent'] as num?)?.toDouble() ?? 10,
      vatIncluded: json['vat_included'] as bool? ?? true,
    );
  }
}
