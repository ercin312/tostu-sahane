import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../../core/network/api_response.dart';
import '../../models/payment_models.dart';

class PaymentRemoteDataSource {
  PaymentRemoteDataSource(this._dio);

  final Dio _dio;

  Future<PaytrInitModel> initPaytr(PaytrInitRequest request) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.paytrInit,
      data: request.toJson(),
    );
    return ApiResponse.parseData(
      response.data!,
      PaytrInitModel.fromJson,
    );
  }

  Future<PaytrVerifyModel> verifyPaytr(String merchantOid) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.paytrVerify,
      data: {'merchant_oid': merchantOid},
    );
    return ApiResponse.parseData(
      response.data!,
      PaytrVerifyModel.fromJson,
    );
  }
}
