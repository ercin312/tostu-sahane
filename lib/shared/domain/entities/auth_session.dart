import 'user.dart';

class AuthSessionResult {
  const AuthSessionResult({
    required this.userId,
    required this.name,
    required this.role,
    required this.phone,
    this.email,
    this.accessToken,
    this.refreshToken,
    this.branchId,
    this.username,
  });

  final String userId;
  final String name;
  final UserRole role;
  final String phone;
  final String? email;
  final String? accessToken;
  final String? refreshToken;
  final String? branchId;
  final String? username;
}
