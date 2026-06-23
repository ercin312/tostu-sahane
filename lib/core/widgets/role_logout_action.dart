import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/route_paths.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../localization/locale_keys.dart';

/// Şube, kurye ve yönetici ekranları için AppBar çıkış butonu.
class RoleLogoutAction extends ConsumerWidget {
  const RoleLogoutAction({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(LocaleKeys.authLogout.tr()),
        content: Text(LocaleKeys.authLogoutConfirm.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocaleKeys.commonCancel.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(LocaleKeys.authLogout.tr()),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (context.mounted) context.go(RoutePaths.authLogin);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: LocaleKeys.authLogout.tr(),
      icon: const Icon(Icons.logout),
      onPressed: () => _logout(context, ref),
    );
  }
}
