import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/route_paths.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/localization/localization_service.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/app_button.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';

class CustomerProfilePage extends ConsumerWidget {
  const CustomerProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider)!;

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.customerProfileTitle.tr())),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(auth.user.name.tr()),
            subtitle: Text(
              auth.email?.isNotEmpty == true ? auth.email! : auth.phone,
            ),
          ),
          const Divider(),
          _ProfileTile(
            icon: Icons.receipt_long_outlined,
            titleKey: LocaleKeys.customerOrdersTitle,
            onTap: () => context.go(RoutePaths.customerOrders),
          ),
          _ProfileTile(
            icon: Icons.location_on_outlined,
            titleKey: LocaleKeys.profileAddresses,
            onTap: () => context.push(RoutePaths.customerAddresses),
          ),
          _ProfileTile(
            icon: Icons.credit_card,
            titleKey: LocaleKeys.profileSavedCards,
            onTap: () => context.push(RoutePaths.customerSavedCards),
          ),
          _ProfileTile(
            icon: Icons.favorite_border,
            titleKey: LocaleKeys.profileFavorites,
            onTap: () => context.push(RoutePaths.customerFavorites),
          ),
          _ProfileTile(
            icon: Icons.settings,
            titleKey: LocaleKeys.profileSettings,
            onTap: () => _showLanguageSheet(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            labelKey: LocaleKeys.authLogout,
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go(RoutePaths.authLogin);
            },
          ),
        ],
      ),
    );
  }

  void _showLanguageSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(LocaleKeys.settingsLanguage.tr())),
              ListTile(
                title: Text(LocaleKeys.settingsLanguageTr.tr()),
                onTap: () {
                  LocalizationService.changeLocale(
                    context,
                    const Locale('tr', 'TR'),
                  );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(LocaleKeys.settingsLanguageEn.tr()),
                onTap: () {
                  LocalizationService.changeLocale(
                    context,
                    const Locale('en', 'US'),
                  );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.titleKey,
    this.onTap,
  });

  final IconData icon;
  final String titleKey;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(titleKey.tr()),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
