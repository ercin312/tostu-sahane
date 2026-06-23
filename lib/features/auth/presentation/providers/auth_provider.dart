import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';



import '../../../../core/localization/locale_keys.dart';

import '../../../../core/network/dio_provider.dart';

import '../../../../core/notifications/notification_service.dart';

import '../../../../shared/domain/entities/auth.dart';

import '../../../../shared/domain/entities/auth_session.dart';

import '../../../../shared/domain/entities/user.dart';

import '../../../../shared/domain/usecases/auth/login_with_email_password_use_case.dart';

import '../../../../shared/domain/usecases/auth/send_otp_use_case.dart';

import '../../../../shared/domain/usecases/auth/verify_otp_use_case.dart';

import '../../../../shared/presentation/providers/repository_providers.dart';
import '../../../../shared/presentation/providers/use_case_providers.dart';



enum LoginMethod { phone, email }



enum EmailAuthMode { otp, password }



class AuthState {

  const AuthState({

    required this.user,

    required this.phone,

    this.email,

  });



  final User user;

  final String phone;

  final String? email;

}



class AuthNotifier extends Notifier<AuthState?> {

  static const _userKey = 'auth_user_id';

  static const _phoneKey = 'auth_phone';

  static const _emailKey = 'auth_email';

  static const _roleKey = 'auth_role';

  static const _nameKey = 'auth_name';
  static const _branchKey = 'auth_branch_id';
  static const _usernameKey = 'auth_username';



  String? _pendingPhone;

  String? _pendingEmail;

  UserRole? _pendingRole;

  LoginMethod? _pendingMethod;

  EmailAuthMode _emailAuthMode = EmailAuthMode.otp;



  Future<void> loadSavedAuth() async {

    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString(_userKey);

    final phone = prefs.getString(_phoneKey);

    final email = prefs.getString(_emailKey);

    final roleName = prefs.getString(_roleKey);

    final name = prefs.getString(_nameKey);

    final branchId = prefs.getString(_branchKey);
    final username = prefs.getString(_usernameKey);

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

      );

    }

  }



  @override

  AuthState? build() => null;



  void setPendingPhoneLogin(String phone, UserRole role) {

    _pendingPhone = phone;

    _pendingEmail = null;

    _pendingRole = role;

    _pendingMethod = LoginMethod.phone;

  }



  void setPendingEmailLogin(String email, UserRole role, EmailAuthMode mode) {

    _pendingEmail = email.trim().toLowerCase();

    _pendingPhone = null;

    _pendingRole = role;

    _pendingMethod = LoginMethod.email;

    _emailAuthMode = mode;

  }



  LoginMethod? get pendingMethod => _pendingMethod;

  EmailAuthMode get emailAuthMode => _emailAuthMode;

  String? get pendingPhone => _pendingPhone;

  String? get pendingEmail => _pendingEmail;

  UserRole? get pendingRole => _pendingRole;



  Future<bool> sendOtp() async {

    if (_pendingRole == null) return false;



    await ref.read(sendOtpUseCaseProvider).call(

          SendOtpParams(

            channel: _pendingMethod == LoginMethod.email

                ? AuthOtpChannel.email

                : AuthOtpChannel.phone,

            phone: _pendingPhone,

            email: _pendingEmail,

            role: _pendingRole!.name,

          ),

        );

    return true;

  }



  Future<bool> verifyOtp(String otp) async {

    if (_pendingRole == null) return false;



    try {

      final session = await ref.read(verifyOtpUseCaseProvider).call(

            VerifyOtpParams(

              channel: _pendingMethod == LoginMethod.email

                  ? AuthOtpChannel.email

                  : AuthOtpChannel.phone,

              otp: otp,

              role: _pendingRole!,

              phone: _pendingPhone,

              email: _pendingEmail,

            ),

          );

      await _persistSession(session);

      _clearPending();

      return true;

    } on AuthCredentialsException {

      return false;

    } catch (_) {

      return false;

    }

  }



  Future<bool> loginWithEmailPassword(String email, String password) async {

    if (_pendingRole == null) return false;



    try {

      final session = await ref.read(loginWithEmailPasswordUseCaseProvider).call(

            LoginWithEmailPasswordParams(

              email: email.trim().toLowerCase(),

              password: password,

              role: _pendingRole!,

            ),

          );

      await _persistSession(session);

      _clearPending();

      return true;

    } on AuthCredentialsException {

      return false;

    } catch (_) {

      return false;

    }

  }



  Future<void> _persistSession(AuthSessionResult session) async {

    final user = User(

      id: session.userId,

      name: session.role == UserRole.waiter ||
              session.role == UserRole.kitchenStaff
          ? session.name
          : _nameForRole(session.role),

      role: session.role,

      branchId: session.branchId,
      username: session.username,

    );



    state = AuthState(

      user: user,

      phone: session.phone,

      email: session.email,

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



  void _clearPending() {

    _pendingPhone = null;

    _pendingEmail = null;

    _pendingRole = null;

    _pendingMethod = null;

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

    _clearPending();



    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_userKey);

    await prefs.remove(_phoneKey);

    await prefs.remove(_emailKey);

    await prefs.remove(_roleKey);

    await prefs.remove(_nameKey);
    await prefs.remove(_branchKey);



    final storage = ref.read(secureStorageProvider);

    await storage.delete(key: ApiTokens.accessToken);

    await storage.delete(key: ApiTokens.refreshToken);

  }

}



final authProvider = NotifierProvider<AuthNotifier, AuthState?>(

  AuthNotifier.new,

);


