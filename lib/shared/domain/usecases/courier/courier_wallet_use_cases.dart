import '../../entities/courier_cash_remittance.dart';
import '../../entities/courier_wallet.dart';
import '../use_case.dart';
import '../../../data/repositories/courier_wallet_repository.dart';

class GetCourierWalletSummaryUseCase
    extends UseCase<CourierWalletSummary, String> {
  GetCourierWalletSummaryUseCase(this._repository);

  final CourierWalletRepository _repository;

  @override
  Future<CourierWalletSummary> call(String courierId) {
    return _repository.getSummary(courierId);
  }
}

class GetCourierWalletHistoryUseCase
    extends UseCase<List<CourierWalletEntry>, String> {
  GetCourierWalletHistoryUseCase(this._repository);

  final CourierWalletRepository _repository;

  @override
  Future<List<CourierWalletEntry>> call(String courierId) {
    return _repository.getHistory(courierId);
  }
}

class RequestCourierRemittanceParams {
  const RequestCourierRemittanceParams({
    required this.courierId,
    required this.courierName,
    required this.amount,
    this.courierNote,
  });

  final String courierId;
  final String courierName;
  final double amount;
  final String? courierNote;
}

class RequestCourierRemittanceUseCase
    extends UseCase<CourierCashRemittance, RequestCourierRemittanceParams> {
  RequestCourierRemittanceUseCase(this._repository);

  final CourierWalletRepository _repository;

  @override
  Future<CourierCashRemittance> call(RequestCourierRemittanceParams params) async {
    final branchId = await _repository.resolveCourierBranchId(params.courierId);
    return _repository.requestRemittance(
      courierId: params.courierId,
      courierName: params.courierName,
      branchId: branchId,
      amount: params.amount,
      courierNote: params.courierNote,
    );
  }
}
