import '../../entities/auth.dart';
import '../use_case.dart';
import '../../../data/repositories/app_repositories.dart';

class SendOtpParams {
  const SendOtpParams({
    required this.channel,
    this.phone,
    this.email,
    required this.role,
  });

  final AuthOtpChannel channel;
  final String? phone;
  final String? email;
  final String role;
}

class SendOtpUseCase extends UseCase<void, SendOtpParams> {
  SendOtpUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<void> call(SendOtpParams params) async {
    if (params.channel == AuthOtpChannel.email && params.email != null) {
      await _repository.sendEmailOtp(params.email!, params.role);
      return;
    }
    if (params.phone != null) {
      await _repository.sendOtp(params.phone!, params.role);
    }
  }
}
