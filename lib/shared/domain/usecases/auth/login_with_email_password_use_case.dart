import '../../entities/auth.dart';
import '../../entities/auth_session.dart';
import '../../entities/user.dart';
import '../use_case.dart';
import '../../../data/repositories/app_repositories.dart';
import '../../../data/models/api_models.dart';

class LoginWithEmailPasswordParams {
  const LoginWithEmailPasswordParams({
    required this.email,
    required this.password,
    required this.role,
  });

  final String email;
  final String password;
  final UserRole role;
}

class LoginWithEmailPasswordUseCase
    extends UseCase<AuthSessionResult, LoginWithEmailPasswordParams> {
  LoginWithEmailPasswordUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<AuthSessionResult> call(LoginWithEmailPasswordParams params) async {
    try {
      final result = await _repository.loginWithEmailPassword(
        params.email,
        params.password,
        params.role.name,
      );
      return _map(result, params.email);
    } on AuthCredentialsException {
      rethrow;
    }
  }

  AuthSessionResult _map(AuthUserModel model, String email) {
    return AuthSessionResult(
      userId: model.id,
      name: model.name,
      role: UserRole.values.byName(model.role),
      phone: model.phone,
      email: email,
      accessToken: model.accessToken,
      refreshToken: model.refreshToken,
      branchId: model.branchId,
      username: model.username,
    );
  }
}
