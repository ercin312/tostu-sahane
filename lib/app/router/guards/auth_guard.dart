import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/guest_access.dart';
import '../../../core/utils/platform_layout_utils.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../shared/domain/entities/user.dart';
import '../route_paths.dart';

String? authRedirect(Ref ref, GoRouterState state) {
  final auth = ref.read(authProvider);
  final path = state.uri.path;

  final isAuthRoute = path == RoutePaths.authLogin ||
      path == RoutePaths.authOtp ||
      path == RoutePaths.authRegister;
  final isAddressOnboarding = path == RoutePaths.authAddressOnboarding;
  final isPhoneOnboarding = path == RoutePaths.authPhoneOnboarding;
  final isSplash = path == RoutePaths.splash;

  if (auth == null) {
    if (isAuthRoute || isSplash || GuestAccess.isBrowsablePath(path)) {
      return null;
    }
    // Staff / ops / account routes stay behind login.
    if (PlatformLayout.isOpsDesktop) {
      return RoutePaths.authLogin;
    }
    return GuestAccess.loginLocation(redirectTo: path);
  }

  if (auth.needsPhoneOnboarding &&
      auth.user.role == UserRole.customer &&
      !isPhoneOnboarding) {
    return RoutePaths.authPhoneOnboarding;
  }

  if (auth.needsAddressOnboarding &&
      auth.user.role == UserRole.customer &&
      !isAddressOnboarding &&
      !isPhoneOnboarding) {
    return RoutePaths.authAddressOnboarding;
  }

  if (isPhoneOnboarding) {
    if (auth.user.role != UserRole.customer) {
      return RoutePaths.homeForRole(auth.user.role.name);
    }
    if (!auth.needsPhoneOnboarding) {
      return auth.needsAddressOnboarding
          ? RoutePaths.authAddressOnboarding
          : RoutePaths.homeForRole(auth.user.role.name);
    }
    return null;
  }

  if (isAddressOnboarding) {
    if (auth.user.role != UserRole.customer) {
      return RoutePaths.homeForRole(auth.user.role.name);
    }
    return null;
  }

  if (isAuthRoute || isSplash) {
    final redirect = GuestAccess.redirectFromUri(state.uri);
    if (redirect != null && auth.user.role == UserRole.customer) {
      return redirect;
    }
    return RoutePaths.homeForRole(auth.user.role.name);
  }

  final role = auth.user.role;
  if (path.startsWith('/customer') && role != UserRole.customer) {
    return RoutePaths.homeForRole(role.name);
  }
  if (path.startsWith('/branch') &&
      role != UserRole.branchManager &&
      role != UserRole.branchStaff &&
      role != UserRole.waiter &&
      role != UserRole.kitchenStaff) {
    return RoutePaths.homeForRole(role.name);
  }
  if (role == UserRole.waiter && !path.startsWith('/branch/waiter')) {
    return RoutePaths.branchWaiter;
  }
  if (role == UserRole.kitchenStaff &&
      !path.startsWith(RoutePaths.branchKitchen)) {
    return RoutePaths.branchKitchen;
  }
  if ((role == UserRole.branchManager || role == UserRole.branchStaff) &&
      path.startsWith('/branch/waiter')) {
    return RoutePaths.branchDashboard;
  }
  if ((role == UserRole.branchManager ||
          role == UserRole.branchStaff ||
          role == UserRole.waiter) &&
      path.startsWith(RoutePaths.branchKitchen)) {
    return RoutePaths.homeForRole(role.name);
  }
  if (path.startsWith('/courier') && role != UserRole.courier) {
    return RoutePaths.homeForRole(role.name);
  }
  if (path.startsWith('/admin') && role != UserRole.superAdmin) {
    return RoutePaths.homeForRole(role.name);
  }

  return null;
}
