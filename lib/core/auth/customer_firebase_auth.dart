import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../shared/domain/entities/auth.dart';
import '../../shared/domain/entities/auth_session.dart';
import '../../shared/domain/entities/user.dart';

/// Müşteri: e-posta/şifre + Google + Apple (Firebase Auth).
/// SMS OTP kullanılmaz.
class CustomerFirebaseAuth {
  CustomerFirebaseAuth({
    fb.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? fb.FirebaseAuth.instance,
        _db = firestore ?? FirebaseFirestore.instance;

  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;
  var _googleReady = false;

  Future<void> _ensureGoogle() async {
    if (_googleReady) return;
    // Web client ID — Android'de Firebase idToken için gerekli (Play SHA sonrası da).
    await GoogleSignIn.instance.initialize(
      serverClientId:
          '512275443807-oqepniuq84128ao36d5uh5c0e6diqa3l.apps.googleusercontent.com',
    );
    _googleReady = true;
  }

  String normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0') && digits.length == 11) {
      digits = '90${digits.substring(1)}';
    }
    if (digits.length == 10 && digits.startsWith('5')) {
      digits = '90$digits';
    }
    return digits;
  }

  /// Kayıt: e-posta doğrulama maili gönderilir; oturum açılmaz.
  Future<void> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final normalizedPhone = normalizePhone(phone);
    if (normalizedPhone.length < 12) {
      throw const AuthCredentialsException('auth_invalid_phone');
    }
    if (password.trim().length < 6) {
      throw const AuthCredentialsException('auth_invalid_password');
    }

    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw const AuthCredentialsException('auth_register_failed');
      }
      await user.updateDisplayName(name.trim());
      await user.sendEmailVerification();
    await _upsertProfile(
      uid: user.uid,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: normalizedPhone,
      provider: 'password',
      needsAddressOnboarding: true,
    );
      await _auth.signOut();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthCredentialsException(_mapFirebaseCode(e.code));
    }
  }

  Future<AuthSessionResult> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw const AuthCredentialsException('auth_invalid_credentials');
      }
      await user.reload();
      final fresh = _auth.currentUser ?? user;
      if (!fresh.emailVerified) {
        try {
          await fresh.sendEmailVerification();
        } catch (_) {}
        await _auth.signOut();
        throw const AuthCredentialsException('auth_email_not_verified');
      }
      return _sessionFromFirebaseUser(fresh, providerHint: 'password');
    } on fb.FirebaseAuthException catch (e) {
      throw AuthCredentialsException(_mapFirebaseCode(e.code));
    }
  }

  Future<AuthSessionResult> loginWithGoogle() async {
    try {
      await _ensureGoogle();
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        throw const AuthCredentialsException('auth_google_unavailable');
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthCredentialsException('auth_google_failed');
      }
      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      final cred = await _auth.signInWithCredential(credential);
      final user = cred.user;
      if (user == null) {
        throw const AuthCredentialsException('auth_google_failed');
      }
      return _sessionFromFirebaseUser(
        user,
        providerHint: 'google',
        fallbackName: account.displayName,
      );
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AuthCredentialsException('auth_cancelled');
      }
      debugPrint('Google sign-in failed: $e');
      throw const AuthCredentialsException('auth_google_failed');
    } on fb.FirebaseAuthException catch (e) {
      throw AuthCredentialsException(_mapFirebaseCode(e.code));
    }
  }

  Future<AuthSessionResult> loginWithApple() async {
    try {
      final rawNonce = _randomNonce();
      final nonce = _sha256ofString(rawNonce);
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final idToken = apple.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthCredentialsException('auth_apple_failed');
      }
      final oauth = fb.OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
        accessToken: apple.authorizationCode,
      );
      final cred = await _auth.signInWithCredential(oauth);
      final user = cred.user;
      if (user == null) {
        throw const AuthCredentialsException('auth_apple_failed');
      }
      final fullName = [
        apple.givenName,
        apple.familyName,
      ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
      return _sessionFromFirebaseUser(
        user,
        providerHint: 'apple',
        fallbackName: fullName.isEmpty ? null : fullName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthCredentialsException('auth_cancelled');
      }
      throw const AuthCredentialsException('auth_apple_failed');
    } on fb.FirebaseAuthException catch (e) {
      throw AuthCredentialsException(_mapFirebaseCode(e.code));
    }
  }

  Future<void> clearNeedsAddressFlag(String uid) async {
    await _db.collection('users').doc(uid).set({
      'needs_address_onboarding': false,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> completePhone({
    required String uid,
    required String phone,
    String? name,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized.length < 12) {
      throw const AuthCredentialsException('auth_invalid_phone');
    }
    await _db.collection('users').doc(uid).set({
      'phone': normalized,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      'role': 'customer',
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw AuthCredentialsException(_mapFirebaseCode(e.code));
    }
  }

  Future<void> signOut() async {
    try {
      await _ensureGoogle();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  Future<AuthSessionResult> _sessionFromFirebaseUser(
    fb.User user, {
    required String providerHint,
    String? fallbackName,
  }) async {
    final email = user.email?.trim().toLowerCase() ?? '';
    final name = (user.displayName?.trim().isNotEmpty == true)
        ? user.displayName!.trim()
        : (fallbackName?.trim().isNotEmpty == true
            ? fallbackName!.trim()
            : (email.isNotEmpty ? email.split('@').first : 'Müşteri'));

    final existing = await _db.collection('users').doc(user.uid).get();
    final data = existing.data() ?? {};
    final phone = (data['phone'] as String?)?.trim() ?? '';
    final needsAddress = data['needs_address_onboarding'] == true;

    await _upsertProfile(
      uid: user.uid,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : name,
      email: email.isNotEmpty
          ? email
          : ((data['email'] as String?) ?? ''),
      phone: phone,
      provider: providerHint,
    );

    final token = await user.getIdToken();
    return AuthSessionResult(
      userId: user.uid,
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : name,
      role: UserRole.customer,
      phone: phone,
      email: email.isNotEmpty ? email : null,
      accessToken: token,
      refreshToken: user.refreshToken,
      needsAddressOnboarding: needsAddress,
    );
  }

  Future<void> _upsertProfile({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required String provider,
    bool needsAddressOnboarding = false,
  }) async {
    final ref = _db.collection('users').doc(uid);
    final snap = await ref.get();
    final payload = <String, dynamic>{
      'name': name,
      'role': 'customer',
      'auth_provider': provider,
      'updated_at': FieldValue.serverTimestamp(),
      if (email.isNotEmpty) 'email': email,
      if (phone.isNotEmpty) 'phone': phone,
      if (needsAddressOnboarding) 'needs_address_onboarding': true,
    };
    if (!snap.exists) {
      payload['created_at'] = FieldValue.serverTimestamp();
    }
    await ref.set(payload, SetOptions(merge: true));
  }

  String _mapFirebaseCode(String code) {
    return switch (code) {
      'email-already-in-use' => 'auth_email_already_in_use',
      'invalid-email' => 'auth_invalid_email',
      'weak-password' => 'auth_invalid_password',
      'user-not-found' || 'wrong-password' || 'invalid-credential' =>
        'auth_invalid_credentials',
      'too-many-requests' => 'auth_too_many_requests',
      'network-request-failed' => 'auth_network_error',
      _ => 'auth_register_failed',
    };
  }

  String _randomNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
