import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/shared/data/models/api_models.dart';

/// Aynı username ile birden fazla ops kullanıcısı varken şifre eşleşmesini doğrular.
AdminUserModel? pickOpsUserByUsernameAndPassword(
  List<AdminUserModel> users,
  String username,
  String password,
) {
  final needle = username.trim().toLowerCase();
  final passwordTrimmed = password.trim();
  for (final user in users) {
    final candidate = user.username?.trim().toLowerCase();
    if (candidate != needle) continue;
    if (user.isActive != true) continue;
    if ((user.password?.trim() ?? '') == passwordTrimmed) return user;
  }
  return null;
}

void main() {
  test('duplicate usernames resolve by matching password', () {
    const users = [
      AdminUserModel(
        id: 'old',
        name: 'Eski',
        role: 'waiter',
        phone: '',
        isActive: true,
        username: 'garson1',
        password: 'OLD_PASS',
      ),
      AdminUserModel(
        id: 'new',
        name: 'Yeni',
        role: 'waiter',
        phone: '',
        isActive: true,
        username: 'garson1',
        password: 'Garson1',
      ),
    ];

    final matched = pickOpsUserByUsernameAndPassword(users, 'garson1', 'Garson1');
    expect(matched?.id, 'new');
    expect(
      pickOpsUserByUsernameAndPassword(users, 'garson1', 'wrong'),
      isNull,
    );
  });
}
