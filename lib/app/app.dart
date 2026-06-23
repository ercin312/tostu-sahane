import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_keys.dart';
import '../core/utils/platform_layout_utils.dart';
import '../core/theme/app_theme.dart';
import 'providers/app_providers.dart';

class TostuSahaneApp extends ConsumerWidget {
  const TostuSahaneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: PlatformLayout.isOpsDesktop
          ? LocaleKeys.appNameOps.tr()
          : LocaleKeys.appName.tr(),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
