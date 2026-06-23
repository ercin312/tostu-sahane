import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../shared/domain/entities/user.dart';
import '../providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        final auth = ref.read(authProvider);
        if (auth != null) {
          context.go(_homeForRole(auth.user.role));
        } else {
          context.go(RoutePaths.authLogin);
        }
      });
    });
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
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogo(height: 80, onPrimary: true),
            const SizedBox(height: AppSpacing.md),
            Text(
              LocaleKeys.appName.tr(),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: AppColors.white,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const CircularProgressIndicator(color: AppColors.white),
            const SizedBox(height: AppSpacing.md),
            Text(
              LocaleKeys.splashLoading.tr(),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.white,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
