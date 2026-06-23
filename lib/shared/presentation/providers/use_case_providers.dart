import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/usecases/auth/login_with_email_password_use_case.dart';
import '../../domain/usecases/auth/send_otp_use_case.dart';
import '../../domain/usecases/auth/verify_otp_use_case.dart';
import '../../domain/usecases/orders/place_order_use_case.dart';
import 'repository_providers.dart';

export 'cash_remittance_providers.dart';

final sendOtpUseCaseProvider = Provider<SendOtpUseCase>((ref) {
  return SendOtpUseCase(ref.watch(authRepositoryProvider));
});

final verifyOtpUseCaseProvider = Provider<VerifyOtpUseCase>((ref) {
  return VerifyOtpUseCase(ref.watch(authRepositoryProvider));
});

final loginWithEmailPasswordUseCaseProvider =
    Provider<LoginWithEmailPasswordUseCase>((ref) {
  return LoginWithEmailPasswordUseCase(ref.watch(authRepositoryProvider));
});

final placeOrderUseCaseProvider = Provider<PlaceOrderUseCase>((ref) {
  return PlaceOrderUseCase(ref.watch(orderRepositoryProvider));
});
