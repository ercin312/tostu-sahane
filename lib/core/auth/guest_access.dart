import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';

/// Apple 5.1.1(v): menu/product browse must work without an account.
abstract final class GuestAccess {
  static const redirectQueryKey = 'redirect';

  static bool isBrowsablePath(String path) {
    if (path == RoutePaths.customerHome) return true;
    if (path == RoutePaths.customerCart) return true;
    if (RegExp(r'^/customer/product/[^/]+$').hasMatch(path)) return true;
    return false;
  }

  static String loginLocation({String? redirectTo}) {
    if (redirectTo == null || redirectTo.isEmpty) {
      return RoutePaths.authLogin;
    }
    final encoded = Uri.encodeComponent(redirectTo);
    return '${RoutePaths.authLogin}?$redirectQueryKey=$encoded';
  }

  static String? redirectFromUri(Uri uri) {
    final value = uri.queryParameters[redirectQueryKey]?.trim();
    if (value == null || value.isEmpty) return null;
    if (!value.startsWith('/customer')) return null;
    return value;
  }

  /// Returns true when the user is already signed in.
  /// Otherwise navigates to login (keeping [redirectTo] for after success).
  static bool requireAuth(
    BuildContext context,
    WidgetRef ref, {
    required String redirectTo,
  }) {
    if (ref.read(authProvider) != null) return true;
    context.push(loginLocation(redirectTo: redirectTo));
    return false;
  }
}
