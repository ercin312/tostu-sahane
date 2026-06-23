import 'package:dio/dio.dart';

import '../constants/app_constants.dart';

class DioClient {
  DioClient({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.apiBaseUrl,
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 30),
              ),
            );

  final Dio _dio;

  Dio get instance => _dio;
}
