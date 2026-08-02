import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/customer_firebase_auth.dart';
import '../../../../core/localization/locale_keys.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/notifications/notification_service.dart';
import '../../../../core/utils/platform_layout_utils.dart';
import '../../../../shared/data/datasources/local/local_datasources.dart';
import '../../../../shared/domain/entities/auth.dart';
import '../../../../shared/domain/entities/auth_session.dart';
import '../../../../shared/domain/entities/user.dart';
import '../../../../shared/domain/usecases/auth/login_with_email_password_use_case.dart';
import '../../../../shared/presentation/providers/repository_providers.dart';
import '../../../../shared/presentation/providers/use_case_providers.dart';

class AuthState {
  const AuthState({
    required this.user,
    required this.phone,
    this.email,
    this.needsAddressOnboarding = false,
    this.needsPhoneOnboarding = false,
  });

  final User user;
  final String phone;
  final String? email;
  final bool needsAddressOnboarding;
  final bool needsPhoneOnboarding;
}

class AuthNotifier extends Notifier<AuthState?> {
  static const _userKey = 'auth_user_id';
  static const _phoneKey = 'auth_phone';
  static const _emailKey = 'auth_email';
  static const _roleKey = 'auth_role';
  static const _nameKey = 'auth_name';
  static const _branchKey = 'auth_branch_id';
  static const _usernameKey = 'auth_username';
  static const _needsAddressKey = 'auth_needs_address';
  static const _needsPhoneKey = 'auth_needs_phone';

  final _customerAuth = CustomerFirebaseAuth();

  Future<void> loadSavedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userKey);
    final phone = prefs.getString(_phoneKey);
    final email = prefs.getString(_emailKey);
    final roleName = prefs.getString(_roleKey);
    final name = prefs.getString(_nameKey);
    final branchId = prefs.getString(_branchKey);
    final username = prefs.getString(_usernameKey);
    final needsAddress = prefs.getBool(_needsAddressKey) ?? false;
    final needsPhone = prefs.getBool(_needsPhoneKey) ?? false;

    if (userId != null && roleName != null && name != null) {
      state = AuthState(
        user: User(
          id: userId,
          name: name,
          role: UserRole.values.byName(roleName),
          branchId: branchId,
          username: username,
        ),
        phone: phone ?? '',
        email: email,
        needsAddressOnboarding: needsAddress,
        needsPhoneOnboarding: needsPhone,
      );
    }
  }

  @override
  AuthState? build() => null;

  bool get supportsAppleSignIn {
    if (kIsWeb) return false;
    if (PlatformLayout.isOpsDesktop) return false;
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (_) {
      return false;
    }
  }

  /// Müşteri kaydı — e-posta doğrulama gönderilir, oturum açılmaz.
  Future<void> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) {
    return _customerAuth.register(
      name: name,
      email: email,
      phone: phone,
      password: password,
    );
  }

  Future<bool> loginCustomerEmail({
    required String email,
    required String password,
  }) async {
    try {
      final session = await _customerAuth.loginWithEmailPassword(
        email: email,
        password: password,
      );
      await _persistSession(
        session,
        needsAddressOnboarding: session.needsAddressOnboarding,
        needsPhoneOnboarding: session.phone.trim().isEmpty,
      );
      return true;
    } on AuthCredentialsException {
      rethrow;
    }
  }

  Future<bool> loginCustomerGoogle() async {
    final session = await _customerAuth.loginWithGoogle();
    await _persistSession(
      session,
      needsAddressOnboarding: session.needsAddressOnboarding,
      needsPhoneOnboarding: session.phone.trim().isEmpty,
    );
    return true;
  }

  Future<bool> loginCustomerApple() async {
    final session = await _customerAuth.loginWithApple();
    await _persistSession(
      session,
      needsAddressOnboarding: session.needsAddressOnboarding,
      needsPhoneOnboarding: session.phone.trim().isEmpty,
    );
    return true;
  }

  Future<void> completeCustomerPhone(String phone) async {
    final current = state;
    if (current == null || current.user.role != UserRole.customer) {
      throw const AuthCredentialsException('auth_invalid_credentials');
    }
    await _customerAuth.completePhone(
      uid: current.user.id,
      phone: phone,
      name: current.user.name,
    );
    final normalized = _customerAuth.normalizePhone(phone);
    state = AuthState(
      user: current.user,
      phone: normalized,
      email: current.email,
      needsAddressOnboarding: current.needsAddressOnboarding,
      needsPhoneOnboarding: false,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, normalized);
    await prefs.setBool(_needsPhoneKey, false);
  }

  Future<void> sendPasswordReset(String email) =>
      _customerAuth.sendPasswordReset(email);

  /// Personel: kullanıcı adı + şifre (rol ops_users belgesinden gelir).
  Future<bool> loginStaff(String username, String password) async {
    try {
      final session = await ref.read(loginWithEmailPasswordUseCaseProvider).call(
            LoginWithEmailPasswordParams(
              email: username.trim().toLowerCase(),
              password: password,
              role: UserRole.waiter,
            ),
          );
      if (session.role == UserRole.customer) return false;
      await _persistSession(session);
      return true;
    } on AuthCredentialsException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearNeedsAddressOnboarding() async {
    final current = state;
    if (current == null) return;
    state = AuthState(
      user: current.user,
      phone: current.phone,
      email: current.email,
      needsAddressOnboarding: false,
      needsPhoneOnboarding: current.needsPhoneOnboarding,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_needsAddressKey, false);
    try {
      await _customerAuth.clearNeedsAddressFlag(current.user.id);
    } catch (_) {}
  }

  Future<void> _persistSession(
    AuthSessionResult session, {
    bool needsAddressOnboarding = false,
    bool needsPhoneOnboarding = false,
  }) async {
    final user = User(
      id: session.userId,
      name: session.name.isNotEmpty
          ? session.name
          : _nameForRole(session.role),
      role: session.role,
      branchId: session.branchId,
      username: session.username,
    );

    final phoneNeeded =
        session.role == UserRole.customer && needsPhoneOnboarding;
    final addressNeeded = session.role == UserRole.customer &&
        needsAddressOnboarding &&
        !phoneNeeded;

    state = AuthState(
      user: user,
      phone: session.phone,
      email: session.email,
      needsAddressOnboarding: addressNeeded,
      needsPhoneOnboarding: phoneNeeded,
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, user.id);
    await prefs.setString(_phoneKey, state!.phone);
    if (state!.email != null) {
      await prefs.setString(_emailKey, state!.email!);
    } else {
      await prefs.remove(_emailKey);
    }
    await prefs.setString(_roleKey, session.role.name);
    await prefs.setString(_nameKey, user.name);
    await prefs.setBool(_needsAddressKey, state!.needsAddressOnboarding);
    await prefs.setBool(_needsPhoneKey, state!.needsPhoneOnboarding);
    if (session.branchId != null) {
      await prefs.setString(_branchKey, session.branchId!);
    } else {
      await prefs.remove(_branchKey);
    }
    if (session.username != null && session.username!.isNotEmpty) {
      await prefs.setString(_usernameKey, session.username!);
    } else {
      await prefs.remove(_usernameKey);
    }

    final storage = ref.read(secureStorageProvider);
    if (session.accessToken != null) {
      await storage.write(
        key: ApiTokens.accessToken,
        value: session.accessToken,
      );
    }
    if (session.refreshToken != null) {
      await storage.write(
        key: ApiTokens.refreshToken,
        value: session.refreshToken,
      );
    }

    final pushToken = await NotificationService.instance.getToken();
    if (pushToken != null) {
      await ref.read(authRepositoryProvider).registerPushToken(
            pushToken,
            userId: user.id,
            role: user.role.name,
            branchId: user.branchId,
          );
    }
  }

  String _nameForRole(UserRole role) {
    return switch (role) {
      UserRole.customer => LocaleKeys.authRoleCustomer,
      UserRole.branchManager => LocaleKeys.authRoleBranch,
      UserRole.branchStaff => LocaleKeys.authRoleBranchStaff,
      UserRole.waiter => LocaleKeys.authRoleWaiter,
      UserRole.kitchenStaff => LocaleKeys.authRoleKitchenStaff,
      UserRole.courier => LocaleKeys.authRoleCourier,
      UserRole.superAdmin => LocaleKeys.authRoleAdmin,
    };
  }

  Future<void> logout() async {
    state = null;
    try {
      await _customerAuth.signOut();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_roleKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_branchKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_needsAddressKey);
    await prefs.remove(_needsPhoneKey);

    // Personel oturumundan kalan sipariş önbelleği müşteriye sızmasın.
    try {
      await OrderLocalDataSource().clearOrders();
    } catch (_) {}

    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: ApiTokens.accessToken);
    await storage.delete(key: ApiTokens.refreshToken);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState?>(
  AuthNotifier.new,
);
