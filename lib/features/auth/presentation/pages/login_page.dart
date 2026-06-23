import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/platform_layout_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../shared/data/mock/mock_data.dart';
import '../../../../shared/domain/entities/user.dart';
import '../providers/auth_provider.dart';



class LoginPage extends ConsumerStatefulWidget {

  const LoginPage({super.key});



  @override

  ConsumerState<LoginPage> createState() => _LoginPageState();

}



class _LoginPageState extends ConsumerState<LoginPage> {

  final _identifierController = TextEditingController();

  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.customer;

  LoginMethod _loginMethod = LoginMethod.phone;

  EmailAuthMode _emailAuthMode = EmailAuthMode.otp;

  var _obscurePassword = true;

  var _loading = false;

  bool get _isOpsDesktop => PlatformLayout.isOpsDesktop;

  @override
  void initState() {
    super.initState();
    if (_isOpsDesktop) {
      _selectedRole = UserRole.branchManager;
    }
  }

  @override
  void dispose() {

    _identifierController.dispose();

    _passwordController.dispose();

    super.dispose();

  }



  Future<void> _submit() async {
    if (_selectedRole == UserRole.waiter ||
        _selectedRole == UserRole.kitchenStaff) {
      final username = _identifierController.text.trim().toLowerCase();
      if (username.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.authInvalidUsername.tr())),
        );
        return;
      }
      if (_passwordController.text.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.authInvalidPassword.tr())),
        );
        return;
      }

      ref.read(authProvider.notifier).setPendingEmailLogin(
            username,
            _selectedRole,
            EmailAuthMode.password,
          );

      setState(() => _loading = true);
      final ok = await ref.read(authProvider.notifier).loginWithEmailPassword(
            username,
            _passwordController.text,
          );
      setState(() => _loading = false);
      if (!mounted) return;
      if (ok) {
        context.go(RoutePaths.splash);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.authInvalidCredentials.tr())),
        );
      }
      return;
    }

    if (_loginMethod == LoginMethod.phone) {

      final phone = _identifierController.text.replaceAll(RegExp(r'\D'), '');

      if (phone.length < 10) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text(LocaleKeys.authInvalidPhone.tr())),

        );

        return;

      }

      ref.read(authProvider.notifier).setPendingPhoneLogin(phone, _selectedRole);

      setState(() => _loading = true);

      await ref.read(authProvider.notifier).sendOtp();

      setState(() => _loading = false);

      if (mounted) context.push(RoutePaths.authOtp);

      return;

    }



    final email = _identifierController.text.trim().toLowerCase();

    if (!email.contains('@') || !email.contains('.')) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(LocaleKeys.authInvalidEmail.tr())),

      );

      return;

    }



    ref.read(authProvider.notifier).setPendingEmailLogin(

          email,

          _selectedRole,

          _emailAuthMode,

        );



    if (_emailAuthMode == EmailAuthMode.password) {

      if (_passwordController.text.length < 6) {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text(LocaleKeys.authInvalidPassword.tr())),

        );

        return;

      }

      setState(() => _loading = true);

      final ok = await ref.read(authProvider.notifier).loginWithEmailPassword(

            email,

            _passwordController.text,

          );

      setState(() => _loading = false);

      if (!mounted) return;

      if (ok) {

        context.go(RoutePaths.splash);

      } else {

        ScaffoldMessenger.of(context).showSnackBar(

          SnackBar(content: Text(LocaleKeys.authInvalidCredentials.tr())),

        );

      }

      return;

    }



    setState(() => _loading = true);

    await ref.read(authProvider.notifier).sendOtp();

    setState(() => _loading = false);

    if (mounted) context.push(RoutePaths.authOtp);

  }



  @override

  Widget build(BuildContext context) {

    final isOpsUsernameLogin = _selectedRole == UserRole.waiter ||
        _selectedRole == UserRole.kitchenStaff;
    final isEmailPassword = isOpsUsernameLogin ||
        (_loginMethod == LoginMethod.email &&
            _emailAuthMode == EmailAuthMode.password);
    final isOpsRole = _selectedRole == UserRole.branchManager ||
        _selectedRole == UserRole.branchStaff ||
        _selectedRole == UserRole.superAdmin;
    final showWebOpsHint = kIsWeb && isOpsRole;
    final showWindowsOpsHint = _isOpsDesktop;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: PlatformLayout.useDesktopLayout(context) ? 520 : double.infinity,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

              const SizedBox(height: AppSpacing.xl),

              const Center(child: AppLogo(height: 64)),

              const SizedBox(height: AppSpacing.lg),

              Text(

                LocaleKeys.authWelcome.tr(),

                style: Theme.of(context).textTheme.displayLarge,

              ),

              const SizedBox(height: AppSpacing.sm),

              Text(

                LocaleKeys.authSubtitle.tr(),

                style: Theme.of(context).textTheme.bodyLarge?.copyWith(

                      color: AppColors.textSecondary,

                    ),

              ),

              const SizedBox(height: AppSpacing.lg),
              if (showWindowsOpsHint) ...[
                Card(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.desktop_windows, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocaleKeys.authWindowsOpsTitle.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                LocaleKeys.authWindowsOpsHint.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ] else if (showWebOpsHint) ...[
                Card(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.computer, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocaleKeys.authWebOpsTitle.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                LocaleKeys.authWebOpsHint.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (!isOpsUsernameLogin) SegmentedButton<LoginMethod>(

                segments: [

                  ButtonSegment(

                    value: LoginMethod.phone,

                    label: Text(LocaleKeys.authMethodPhone.tr()),

                    icon: const Icon(Icons.phone),

                  ),

                  ButtonSegment(

                    value: LoginMethod.email,

                    label: Text(LocaleKeys.authMethodEmail.tr()),

                    icon: const Icon(Icons.email_outlined),

                  ),

                ],

                selected: {_loginMethod},

                onSelectionChanged: (value) {

                  setState(() {

                    _loginMethod = value.first;

                    _identifierController.clear();

                    _passwordController.clear();

                  });

                },

              ),

              if (_loginMethod == LoginMethod.email && !isOpsUsernameLogin) ...[

                const SizedBox(height: AppSpacing.md),

                SegmentedButton<EmailAuthMode>(

                  segments: [

                    ButtonSegment(

                      value: EmailAuthMode.otp,

                      label: Text(LocaleKeys.authEmailModeOtp.tr()),

                    ),

                    ButtonSegment(

                      value: EmailAuthMode.password,

                      label: Text(LocaleKeys.authEmailModePassword.tr()),

                    ),

                  ],

                  selected: {_emailAuthMode},

                  onSelectionChanged: (value) {

                    setState(() => _emailAuthMode = value.first);

                  },

                ),

              ],

              const SizedBox(height: AppSpacing.xl),

              Text(

                LocaleKeys.authSelectRole.tr(),

                style: Theme.of(context).textTheme.titleLarge,

              ),

              const SizedBox(height: AppSpacing.sm),

              Wrap(

                spacing: AppSpacing.sm,

                children: [
                  if (!_isOpsDesktop)
                  _RoleChip(

                    label: LocaleKeys.authRoleCustomer.tr(),

                    selected: _selectedRole == UserRole.customer,

                    onTap: () =>

                        setState(() => _selectedRole = UserRole.customer),

                  ),

                  _RoleChip(

                    label: LocaleKeys.authRoleBranch.tr(),

                    selected: _selectedRole == UserRole.branchManager,

                    onTap: () =>

                        setState(() => _selectedRole = UserRole.branchManager),

                  ),

                  _RoleChip(

                    label: LocaleKeys.authRoleBranchStaff.tr(),

                    selected: _selectedRole == UserRole.branchStaff,

                    onTap: () =>

                        setState(() => _selectedRole = UserRole.branchStaff),

                  ),

                  _RoleChip(

                    label: LocaleKeys.authRoleWaiter.tr(),

                    selected: _selectedRole == UserRole.waiter,

                    onTap: () => setState(() {
                      _selectedRole = UserRole.waiter;
                      _loginMethod = LoginMethod.email;
                      _emailAuthMode = EmailAuthMode.password;
                    }),

                  ),

                  _RoleChip(

                    label: LocaleKeys.authRoleKitchenStaff.tr(),

                    selected: _selectedRole == UserRole.kitchenStaff,

                    onTap: () => setState(() {
                      _selectedRole = UserRole.kitchenStaff;
                      _loginMethod = LoginMethod.email;
                      _emailAuthMode = EmailAuthMode.password;
                    }),

                  ),

                  if (!_isOpsDesktop)
                  _RoleChip(

                    label: LocaleKeys.authRoleCourier.tr(),

                    selected: _selectedRole == UserRole.courier,

                    onTap: () => setState(() => _selectedRole = UserRole.courier),

                  ),

                  _RoleChip(

                    label: LocaleKeys.authRoleAdmin.tr(),

                    selected: _selectedRole == UserRole.superAdmin,

                    onTap: () =>

                        setState(() => _selectedRole = UserRole.superAdmin),

                  ),

                ],

              ),

              const SizedBox(height: AppSpacing.lg),

              TextField(

                controller: _identifierController,

                keyboardType: isOpsUsernameLogin
                    ? TextInputType.text
                    : (_loginMethod == LoginMethod.phone
                        ? TextInputType.phone
                        : TextInputType.emailAddress),

                decoration: InputDecoration(

                  labelText: isOpsUsernameLogin
                      ? LocaleKeys.authUsernameLabel.tr()
                      : (_loginMethod == LoginMethod.phone
                          ? LocaleKeys.authPhoneLabel.tr()
                          : LocaleKeys.authEmailLabel.tr()),

                  hintText: isOpsUsernameLogin
                      ? LocaleKeys.adminUserUsernameHint.tr()
                      : (_loginMethod == LoginMethod.phone
                          ? LocaleKeys.authPhoneHint.tr()
                          : LocaleKeys.authEmailHint.tr()),

                  prefixIcon: Icon(

                    isOpsUsernameLogin
                        ? Icons.badge_outlined
                        : (_loginMethod == LoginMethod.phone
                            ? Icons.phone
                            : Icons.email_outlined),

                  ),

                  border: OutlineInputBorder(

                    borderRadius: BorderRadius.circular(12),

                  ),

                ),

              ),

              if (isEmailPassword) ...[

                const SizedBox(height: AppSpacing.md),

                TextField(

                  controller: _passwordController,

                  obscureText: _obscurePassword,

                  decoration: InputDecoration(

                    labelText: LocaleKeys.authPasswordLabel.tr(),

                    prefixIcon: const Icon(Icons.lock_outline),

                    suffixIcon: IconButton(

                      icon: Icon(

                        _obscurePassword

                            ? Icons.visibility_outlined

                            : Icons.visibility_off_outlined,

                      ),

                      onPressed: () =>

                          setState(() => _obscurePassword = !_obscurePassword),

                    ),

                    border: OutlineInputBorder(

                      borderRadius: BorderRadius.circular(12),

                    ),

                  ),

                ),

                const SizedBox(height: AppSpacing.sm),

                if (!isOpsUsernameLogin)
                Text(

                  LocaleKeys.authDemoPasswordHint.tr(

                    namedArgs: {'password': MockData.demoPassword},

                  ),

                  style: Theme.of(context).textTheme.bodySmall?.copyWith(

                        color: AppColors.textSecondary,

                      ),

                ),

              ],

              const SizedBox(height: AppSpacing.lg),

              AppButton(

                labelKey: isEmailPassword

                    ? LocaleKeys.authLogin

                    : LocaleKeys.authSendOtp,

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
    ),
  ),
    );
  }
}



class _RoleChip extends StatelessWidget {

  const _RoleChip({

    required this.label,

    required this.selected,

    required this.onTap,

  });



  final String label;

  final bool selected;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    return ChoiceChip(

      label: Text(label),

      selected: selected,

      selectedColor: AppColors.primary.withValues(alpha: 0.15),

      onSelected: (_) => onTap(),

    );

  }

}


