import 'package:dio/dio.dart';

import '../../../../core/network/api_endpoints.dart';
import '../../../domain/entities/order.dart';
import '../../mappers/entity_mappers.dart';
import '../../models/api_models.dart';

class BranchRemoteDataSource {
  BranchRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<BranchModel>> getBranches() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.branches);
    final list = response.data!['data'] as List<dynamic>;
    return list.map((e) => BranchModel.fromJson(e as Map<String, dynamic>)).toList();
  }
}

class ProductRemoteDataSource {
  ProductRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<ProductModel>> getProducts({String? branchId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.products,
      queryParameters: branchId != null ? {'branch_id': branchId} : null,
    );
    final list = response.data!['data'] as List<dynamic>;
    return list.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ProductModel> updateAvailability(String productId, bool isAvailable) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '${ApiEndpoints.products}/$productId',
      data: {'is_available': isAvailable},
    );
    return ProductModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<ProductModel> createProduct(ProductModel product) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.adminProducts,
      data: product.toJson(),
    );
    return ProductModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<ProductModel> updateProduct(ProductModel product) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${ApiEndpoints.adminProducts}/${product.id}',
      data: product.toJson(),
    );
    return ProductModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<void> deleteProduct(String productId) async {
    await _dio.delete<void>('${ApiEndpoints.adminProducts}/$productId');
  }
}

class OrderRemoteDataSource {
  OrderRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<OrderModel>> getOrders() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.orders);
    final list = response.data!['data'] as List<dynamic>;
    return list.map((e) => OrderModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<OrderModel> createOrder(Order order) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.orders,
      data: {'data': EntityMappers.fromOrder(order).toJson()},
    );
    return OrderModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<OrderModel> updateStatus(String orderId, OrderStatus status) async {
    final path = ApiEndpoints.ordersStatus.replaceFirst('{id}', orderId);
    final response = await _dio.patch<Map<String, dynamic>>(
      path,
      data: {'status': status.name},
    );
    return OrderModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<OrderModel> assignCourier(
    String orderId,
    String courierId,
    String courierName,
  ) async {
    final path = ApiEndpoints.ordersAssignCourier.replaceFirst('{id}', orderId);
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: {'courier_id': courierId, 'courier_name': courierName},
    );
    return OrderModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<OrderModel> cancelOrder(String orderId) async {
    final path = ApiEndpoints.ordersStatus.replaceFirst('{id}', orderId);
    final response = await _dio.patch<Map<String, dynamic>>(
      path,
      data: {'status': OrderStatus.cancelled.name},
    );
    return OrderModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }
}

class AuthRemoteDataSource {
  AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<void> sendOtp(String phone, String role) async {
    await _dio.post<void>(
      ApiEndpoints.authSendOtp,
      data: {'phone': phone, 'role': role},
    );
  }

  Future<void> sendEmailOtp(String email, String role) async {
    await _dio.post<void>(
      ApiEndpoints.authSendEmailOtp,
      data: {'email': email, 'role': role},
    );
  }

  Future<AuthUserModel> verifyOtp(String phone, String otp, String role) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authVerifyOtp,
      data: {'phone': phone, 'otp': otp, 'role': role},
    );
    return AuthUserModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<AuthUserModel> verifyEmailOtp(
    String email,
    String otp,
    String role,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authVerifyEmailOtp,
      data: {'email': email, 'otp': otp, 'role': role},
    );
    return AuthUserModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<AuthUserModel> loginWithEmailPassword(
    String email,
    String password,
    String role,
  ) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.authEmailLogin,
      data: {'email': email, 'password': password, 'role': role},
    );
    return AuthUserModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<void> registerPushToken(String token) async {
    await _dio.post<void>(
      ApiEndpoints.pushToken,
      data: {'token': token},
    );
  }
}

class AdminRemoteDataSource {
  AdminRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<BranchModel>> getBranches() async {
    final response =
        await _dio.get<Map<String, dynamic>>(ApiEndpoints.adminBranches);
    final list = response.data!['data'] as List<dynamic>;
    return list.map((e) => BranchModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<AdminUserModel>> getUsers() async {
    final response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.adminUsers);
    final list = response.data!['data'] as List<dynamic>;
    return list.map((e) => AdminUserModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<AdminReportModel> getReports() async {
    final response =
        await _dio.get<Map<String, dynamic>>(ApiEndpoints.adminReports);
    return AdminReportModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<BranchModel> createBranch(BranchModel branch) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.adminBranches,
      data: branch.toJson(),
    );
    return BranchModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<BranchModel> updateBranch(BranchModel branch) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${ApiEndpoints.adminBranches}/${branch.id}',
      data: branch.toJson(),
    );
    return BranchModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<void> deleteBranch(String branchId) async {
    await _dio.delete<void>('${ApiEndpoints.adminBranches}/$branchId');
  }

  Future<AdminUserModel> createUser(AdminUserModel user) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.adminUsers,
      data: user.toJson(),
    );
    return AdminUserModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<AdminUserModel> updateUser(AdminUserModel user) async {
    final response = await _dio.put<Map<String, dynamic>>(
      '${ApiEndpoints.adminUsers}/${user.id}',
      data: user.toJson(),
    );
    return AdminUserModel.fromJson(response.data!['data'] as Map<String, dynamic>);
  }

  Future<void> deleteUser(String userId) async {
    await _dio.delete<void>('${ApiEndpoints.adminUsers}/$userId');
  }
}
