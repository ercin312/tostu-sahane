import '../../entities/auth.dart';
import '../../entities/auth_session.dart';
import '../../entities/user.dart';
import '../use_case.dart';
import '../../../data/repositories/app_repositories.dart';
import '../../../data/models/api_models.dart';

class VerifyOtpParams {
  const VerifyOtpParams({
    required this.channel,
    required this.otp,
    required this.role,
    this.phone,
    this.email,
    this.name,
    this.password,
  });

  final AuthOtpChannel channel;
  final String otp;
  final UserRole role;
  final String? phone;
  final String? email;
  final String? name;
  final String? password;
}

class VerifyOtpUseCase extends UseCase<AuthSessionResult, VerifyOtpParams> {
  VerifyOtpUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<AuthSessionResult> call(VerifyOtpParams params) async {
    final AuthUserModel result;
    if (params.channel == AuthOtpChannel.email && params.email != null) {
      result = await _repository.verifyEmailOtp(
        params.email!,
        params.otp,
        params.role.name,
      );
      return AuthSessionResult(
        userId: result.id,
        name: result.name,
        role: UserRole.values.byName(result.role),
        phone: '',
        email: params.email,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        branchId: result.branchId,
      );
    }
    if (params.phone != null) {
      result = await _repository.verifyOtp(
        params.phone!,
        params.otp,
        params.role.name,
        name: params.name,
        password: params.password,
      );
      return AuthSessionResult(
        userId: result.id,
        name: result.name,
        role: UserRole.values.byName(result.role),
        phone: params.phone!,
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        branchId: result.branchId,
      );
    }
    throw const AuthCredentialsException('auth_invalid_otp');
  }
}
