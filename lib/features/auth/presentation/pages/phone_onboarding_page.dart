import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../shared/domain/entities/auth.dart';
import '../providers/auth_provider.dart';

/// Google/Apple sonrası telefon numarası tamamlama.
class PhoneOnboardingPage extends ConsumerStatefulWidget {
  const PhoneOnboardingPage({super.key});

  @override
  ConsumerState<PhoneOnboardingPage> createState() =>
      _PhoneOnboardingPageState();
}

class _PhoneOnboardingPageState extends ConsumerState<PhoneOnboardingPage> {
  final _phoneController = TextEditingController();
  var _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.authInvalidPhone.tr())),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).completeCustomerPhone(phone);
      if (!mounted) return;
      final auth = ref.read(authProvider);
      if (auth?.needsAddressOnboarding == true) {
        context.go(RoutePaths.authAddressOnboarding);
      } else {
        context.go(RoutePaths.customerHome);
      }
    } on AuthCredentialsException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.authInvalidPhone.tr())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.commonError.tr())),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.authPhoneOnboardingTitle.tr()),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                LocaleKeys.authPhoneOnboardingSubtitle.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: LocaleKeys.authPhoneLabel.tr(),
                  hintText: LocaleKeys.authPhoneHint.tr(),
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                labelKey: LocaleKeys.commonSave,
                onPressed: _loading ? null : _submit,
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.md),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
