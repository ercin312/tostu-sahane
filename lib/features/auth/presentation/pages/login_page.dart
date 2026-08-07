import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_paths.dart';
import '../../../../core/auth/guest_access.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/platform_layout_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_logo.dart';
import '../../../../shared/domain/entities/auth.dart';
import '../../../../shared/domain/entities/user.dart';
import '../providers/auth_provider.dart';

enum _LoginAudience { customer, staff }

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  var _audience = _LoginAudience.customer;
  var _obscurePassword = true;
  var _loading = false;

  bool get _isOpsDesktop => PlatformLayout.isOpsDesktop;

  @override
  void initState() {
    super.initState();
    if (_isOpsDesktop) {
      _audience = _LoginAudience.staff;
    }
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _errorMessage(Object e) {
    final key = e is AuthCredentialsException ? e.messageKey : null;
    return switch (key) {
      'auth_email_not_verified' => LocaleKeys.authEmailNotVerified.tr(),
      'auth_invalid_credentials' => LocaleKeys.authInvalidEmailOrPassword.tr(),
      'auth_cancelled' => LocaleKeys.authCancelled.tr(),
      'auth_google_failed' || 'auth_google_unavailable' =>
        LocaleKeys.authGoogleFailed.tr(),
      'auth_apple_failed' => LocaleKeys.authAppleFailed.tr(),
      'auth_too_many_requests' => LocaleKeys.authTooManyRequests.tr(),
      'auth_network_error' => LocaleKeys.authNetworkError.tr(),
      'auth_invalid_email' => LocaleKeys.authInvalidEmail.tr(),
      _ => LocaleKeys.authInvalidCredentials.tr(),
    };
  }

  Future<void> _goAfterLogin() async {
    final auth = ref.read(authProvider);
    if (auth == null) return;
    if (auth.needsPhoneOnboarding) {
      context.go(RoutePaths.authPhoneOnboarding);
      return;
    }
    if (auth.needsAddressOnboarding) {
      context.go(RoutePaths.authAddressOnboarding);
      return;
    }
    final redirect = GuestAccess.redirectFromUri(GoRouterState.of(context).uri);
    if (redirect != null && auth.user.role == UserRole.customer) {
      context.go(redirect);
      return;
    }
    context.go(RoutePaths.splash);
  }

  Future<void> _submitStaff() async {
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

    setState(() => _loading = true);
    final ok = await ref.read(authProvider.notifier).loginStaff(
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
  }

  Future<void> _submitCustomerEmail() async {
    final email = _identifierController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.authInvalidEmail.tr())),
      );
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.authInvalidPassword.tr())),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).loginCustomerEmail(
            email: email,
            password: _passwordController.text,
          );
      if (!mounted) return;
      await _goAfterLogin();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).loginCustomerGoogle();
      if (!mounted) return;
      await _goAfterLogin();
    } catch (e) {
      if (!mounted) return;
      if (e is AuthCredentialsException && e.messageKey == 'auth_cancelled') {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitApple() async {
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).loginCustomerApple();
      if (!mounted) return;
      await _goAfterLogin();
    } catch (e) {
      if (!mounted) return;
      if (e is AuthCredentialsException && e.messageKey == 'auth_cancelled') {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _identifierController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.authInvalidEmail.tr())),
      );
      return;
    }
    try {
      await ref.read(authProvider.notifier).sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.authPasswordResetSent.tr())),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage(e))),
      );
    }
  }

  Future<void> _submit() async {
    if (_audience == _LoginAudience.staff) {
      await _submitStaff();
    } else {
      await _submitCustomerEmail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isStaff = _audience == _LoginAudience.staff;
    final showApple = !isStaff && ref.read(authProvider.notifier).supportsAppleSignIn;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  PlatformLayout.useDesktopLayout(context) ? 520 : double.infinity,
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
                    isStaff
                        ? LocaleKeys.authStaffSubtitle.tr()
                        : LocaleKeys.authCustomerSubtitle.tr(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  if (!_isOpsDesktop) ...[
                    const SizedBox(height: AppSpacing.lg),
                    SegmentedButton<_LoginAudience>(
                      segments: [
                        ButtonSegment(
                          value: _LoginAudience.customer,
                          label: Text(LocaleKeys.authAudienceCustomer.tr()),
                          icon: const Icon(Icons.person_outline),
                        ),
                        ButtonSegment(
                          value: _LoginAudience.staff,
                          label: Text(LocaleKeys.authAudienceStaff.tr()),
                          icon: const Icon(Icons.badge_outlined),
                        ),
                      ],
                      selected: {_audience},
                      onSelectionChanged: (value) {
                        setState(() {
                          _audience = value.first;
                          _identifierController.clear();
                          _passwordController.clear();
                        });
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  TextField(
                    controller: _identifierController,
                    keyboardType: isStaff
                        ? TextInputType.text
                        : TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: isStaff
                          ? LocaleKeys.authUsernameLabel.tr()
                          : LocaleKeys.authEmailLabel.tr(),
                      hintText: isStaff
                          ? LocaleKeys.adminUserUsernameHint.tr()
                          : LocaleKeys.authEmailHint.tr(),
                      prefixIcon: Icon(
                        isStaff ? Icons.badge_outlined : Icons.email_outlined,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    onSubmitted: (_) => _loading ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: LocaleKeys.authPasswordLabel.tr(),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (!isStaff)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading ? null : _forgotPassword,
                        child: Text(LocaleKeys.authForgotPassword.tr()),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    labelKey: LocaleKeys.authLogin,
                    onPressed: _loading ? null : _submit,
                  ),
                  if (!isStaff) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            LocaleKeys.authOrContinueWith.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _submitGoogle,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: Text(LocaleKeys.authContinueGoogle.tr()),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                    if (showApple) ...[
                      const SizedBox(height: AppSpacing.sm),
                      OutlinedButton.icon(
                        onPressed: _loading ? null : _submitApple,
                        icon: const Icon(Icons.apple, size: 24),
                        label: Text(LocaleKeys.authContinueApple.tr()),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => context.push(RoutePaths.authRegister),
                      child: Text(LocaleKeys.authRegisterLink.tr()),
                    ),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => context.go(RoutePaths.customerHome),
                      child: Text(LocaleKeys.authBrowseMenu.tr()),
                    ),
                  ],
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
