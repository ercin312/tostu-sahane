import 'package:equatable/equatable.dart';

enum UserRole {
  customer,
  branchManager,
  branchStaff,
  waiter,
  kitchenStaff,
  courier,
  superAdmin,
}

class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    required this.role,
    this.branchId,
    this.username,
  });

  final String id;
  final String name;
  final UserRole role;
  final String? branchId;
  /// Garson giriş kodu (ör. garson1) — fişte gösterilir.
  final String? username;

  @override
  List<Object?> get props => [id, name, role, branchId, username];
}
