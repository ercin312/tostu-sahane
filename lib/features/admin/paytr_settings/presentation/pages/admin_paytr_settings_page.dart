import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/config/app_config.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/role_logout_action.dart';
import '../../../../../shared/domain/entities/paytr_settings.dart';
import '../../../../../shared/presentation/providers/paytr_settings_provider.dart';

class AdminPaytrSettingsPage extends ConsumerStatefulWidget {
  const AdminPaytrSettingsPage({super.key});

  @override
  ConsumerState<AdminPaytrSettingsPage> createState() =>
      _AdminPaytrSettingsPageState();
}

class _AdminPaytrSettingsPageState extends ConsumerState<AdminPaytrSettingsPage> {
  final _merchantIdController = TextEditingController();
  final _merchantKeyController = TextEditingController();
  final _merchantSaltController = TextEditingController();
  final _callbackUrlController = TextEditingController();
  final _successUrlController = TextEditingController();
  final _failUrlController = TextEditingController();
  final _vatRateController = TextEditingController();

  var _enabled = false;
  var _sandboxMode = true;
  var _vatIncluded = true;
  var _saving = false;
  var _loaded = false;

  @override
  void dispose() {
    _merchantIdController.dispose();
    _merchantKeyController.dispose();
    _merchantSaltController.dispose();
    _callbackUrlController.dispose();
    _successUrlController.dispose();
    _failUrlController.dispose();
    _vatRateController.dispose();
    super.dispose();
  }

  void _ensureLoaded(PaytrSettings settings) {
    if (_loaded) return;
    _loaded = true;
    _enabled = settings.enabled;
    _sandboxMode = settings.sandboxMode;
    _vatIncluded = settings.vatIncluded;
    _merchantIdController.text = settings.merchantId;
    _merchantKeyController.text = settings.merchantKey;
    _merchantSaltController.text = settings.merchantSalt;
    _callbackUrlController.text = settings.callbackUrl;
    _successUrlController.text = settings.successRedirectUrl;
    _failUrlController.text = settings.failRedirectUrl;
    _vatRateController.text = settings.vatRatePercent.toStringAsFixed(
      settings.vatRatePercent == settings.vatRatePercent.roundToDouble()
          ? 0
          : 1,
    );
  }

  Future<void> _save() async {
    final vatRate = double.tryParse(
      _vatRateController.text.trim().replaceAll(',', '.'),
    );
    if (vatRate == null || vatRate < 0 || vatRate > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminPaytrVatRateInvalid.tr())),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await savePaytrSettings(
        ref,
        PaytrSettings(
          enabled: _enabled,
          sandboxMode: _sandboxMode,
          merchantId: _merchantIdController.text.trim(),
          merchantKey: _merchantKeyController.text.trim(),
          merchantSalt: _merchantSaltController.text.trim(),
          callbackUrl: _callbackUrlController.text.trim(),
          successRedirectUrl: _successUrlController.text.trim(),
          failRedirectUrl: _failUrlController.text.trim(),
          vatRatePercent: vatRate,
          vatIncluded: _vatIncluded,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.adminPaytrSettingsSaved.tr())),
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

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(paytrSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.adminPaytrSettingsTitle.tr()),
        actions: const [RoleLogoutAction()],
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(LocaleKeys.commonError.tr())),
        data: (settings) {
          _ensureLoaded(settings);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                LocaleKeys.adminPaytrSettingsSubtitle.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Card(
                child: SwitchListTile(
                  title: Text(LocaleKeys.adminPaytrEnabled.tr()),
                  subtitle: Text(LocaleKeys.adminPaytrEnabledHint.tr()),
                  value: _enabled,
                  onChanged: (value) => setState(() => _enabled = value),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: SwitchListTile(
                  title: Text(LocaleKeys.adminPaytrSandboxMode.tr()),
                  subtitle: Text(LocaleKeys.adminPaytrSandboxModeHint.tr()),
                  value: _sandboxMode,
                  onChanged: (value) => setState(() => _sandboxMode = value),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        LocaleKeys.adminPaytrCredentialsTitle.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _merchantIdController,
                        decoration: InputDecoration(
                          labelText: LocaleKeys.adminPaytrMerchantId.tr(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _merchantKeyController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: LocaleKeys.adminPaytrMerchantKey.tr(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _merchantSaltController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: LocaleKeys.adminPaytrMerchantSalt.tr(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        LocaleKeys.adminPaytrUrlsTitle.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _callbackUrlController,
                        decoration: InputDecoration(
                          labelText: LocaleKeys.adminPaytrCallbackUrl.tr(),
                          hintText: LocaleKeys.adminPaytrCallbackUrlHint.tr(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _successUrlController,
                        decoration: InputDecoration(
                          labelText: LocaleKeys.adminPaytrSuccessUrl.tr(),
                          hintText: AppConfig.paytrSuccessUrl,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _failUrlController,
                        decoration: InputDecoration(
                          labelText: LocaleKeys.adminPaytrFailUrl.tr(),
                          hintText: AppConfig.paytrFailUrl,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        LocaleKeys.adminPaytrVatTitle.tr(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _vatRateController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: LocaleKeys.adminPaytrVatRate.tr(),
                          hintText: '10',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SegmentedButton<bool>(
                        segments: [
                          ButtonSegment(
                            value: true,
                            label: Text(LocaleKeys.adminPaytrVatIncluded.tr()),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text(LocaleKeys.adminPaytrVatExcluded.tr()),
                          ),
                        ],
                        selected: {_vatIncluded},
                        onSelectionChanged: (selection) {
                          setState(() => _vatIncluded = selection.first);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _vatIncluded
                            ? LocaleKeys.adminPaytrVatIncludedHint.tr()
                            : LocaleKeys.adminPaytrVatExcludedHint.tr(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(LocaleKeys.commonSave.tr()),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
