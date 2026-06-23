import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../shared/domain/entities/user.dart';
import '../route_paths.dart';

String? authRedirect(Ref ref, GoRouterState state) {
  final auth = ref.read(authProvider);
  final path = state.uri.path;

  final isAuthRoute =
      path == RoutePaths.authLogin || path == RoutePaths.authOtp;
  final isSplash = path == RoutePaths.splash;

  if (auth == null) {
    if (isAuthRoute || isSplash) return null;
    return RoutePaths.authLogin;
  }

  if (isAuthRoute || isSplash) {
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
