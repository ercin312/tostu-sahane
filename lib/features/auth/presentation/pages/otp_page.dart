import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../shared/domain/entities/user.dart';
import '../providers/auth_provider.dart';

class OtpPage extends ConsumerStatefulWidget {
  const OtpPage({super.key});

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final _otpController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => _isLoading = true);
    final success =
        await ref.read(authProvider.notifier).verifyOtp(_otpController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      final role = ref.read(authProvider)!.user.role;
      context.go(_homeForRole(role));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.authInvalidOtp.tr())),
      );
    }
  }

  String _homeForRole(UserRole role) {
    return switch (role) {
      UserRole.customer => RoutePaths.customerHome,
      UserRole.branchManager => RoutePaths.branchDashboard,
      UserRole.branchStaff => RoutePaths.branchDashboard,
      UserRole.waiter => RoutePaths.branchWaiter,
      UserRole.kitchenStaff => RoutePaths.branchKitchen,
      UserRole.courier => RoutePaths.courierTasks,
      UserRole.superAdmin => RoutePaths.adminDashboard,
    };
  }

  @override
  Widget build(BuildContext context) {
    final authNotifier = ref.read(authProvider.notifier);
    final isEmail = authNotifier.pendingMethod == LoginMethod.email;
    final destination = isEmail ? authNotifier.pendingEmail : authNotifier.pendingPhone;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                LocaleKeys.authOtpTitle.tr(),
                style: Theme.of(context).textTheme.displayLarge,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                isEmail
                    ? LocaleKeys.authOtpEmailSubtitle.tr(
                        namedArgs: {'email': destination ?? ''},
                      )
                    : LocaleKeys.authOtpSubtitle.tr(),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                LocaleKeys.authDemoOtpHint.tr(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge,
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                labelKey: LocaleKeys.authVerify,
                isLoading: _isLoading,
                onPressed: _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
