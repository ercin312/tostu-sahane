import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../shared/domain/entities/user.dart';
import '../localization/locale_keys.dart';
import '../theme/app_colors.dart';
import '../utils/platform_layout_utils.dart';

/// Windows ops: kasa ↔ yönetim paneli hızlı geçiş (çift ekran / kasa tarafı).
class OpsCashierSwitchFab extends ConsumerWidget {
  const OpsCashierSwitchFab({super.key, required this.child});

  final Widget child;

  static bool showsForRole(UserRole role) {
    return role == UserRole.branchManager ||
        role == UserRole.branchStaff ||
        role == UserRole.superAdmin;
  }

  static bool isCashierPath(String path) {
    return path.startsWith(RoutePaths.branchCashier) ||
        path.startsWith(RoutePaths.adminCashier);
  }

  static String cashierPathFor(UserRole role) {
    return role == UserRole.superAdmin
        ? RoutePaths.adminCashier
        : RoutePaths.branchCashier;
  }

  static String panelPathFor(UserRole role) {
    return role == UserRole.superAdmin
        ? RoutePaths.adminDashboard
        : RoutePaths.branchDashboard;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    if (!PlatformLayout.isOpsDesktop ||
        auth == null ||
        !showsForRole(auth.user.role)) {
      return child;
    }

    final path = GoRouterState.of(context).uri.path;
    final onCashier = isCashierPath(path);
    final role = auth.user.role;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Positioned(
          right: 20,
          bottom: 20,
          child: SafeArea(
            child: Material(
              elevation: 6,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(28),
              color: onCashier ? AppColors.textPrimary : AppColors.primary,
              child: InkWell(
                onTap: () {
                  context.go(
                    onCashier
                        ? panelPathFor(role)
                        : cashierPathFor(role),
                  );
                },
                borderRadius: BorderRadius.circular(28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        onCashier
                            ? Icons.dashboard_outlined
                            : Icons.point_of_sale_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        onCashier
                            ? LocaleKeys.opsPanelFabLabel.tr()
                            : LocaleKeys.opsCashierFabLabel.tr(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
