import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/firestore/firestore_datasource.dart';
import '../../data/datasources/mock_api_datasource.dart';
import '../../data/datasources/remote/payment_remote_datasource.dart';
import '../../data/datasources/remote/remote_datasources.dart';
import '../../data/repositories/app_repositories.dart';
import '../../data/repositories/payment_repository.dart';
import '../../../core/network/dio_provider.dart';

final mockApiDataSourceProvider = Provider<MockApiDataSource>((ref) {
  return MockApiDataSource();
});

final firestoreDataSourceProvider = Provider<FirestoreDataSource>((ref) {
  return FirestoreDataSource();
});

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepository(
    remote: BranchRemoteDataSource(ref.watch(dioProvider)),
    mock: ref.watch(mockApiDataSourceProvider),
    firestore: ref.watch(firestoreDataSourceProvider),
  );
});

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(
    remote: ProductRemoteDataSource(ref.watch(dioProvider)),
    mock: ref.watch(mockApiDataSourceProvider),
    firestore: ref.watch(firestoreDataSourceProvider),
  );
});

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(
    remote: OrderRemoteDataSource(ref.watch(dioProvider)),
    mock: ref.watch(mockApiDataSourceProvider),
    firestore: ref.watch(firestoreDataSourceProvider),
  );
});

final couponRepositoryProvider = Provider<CouponRepository>((ref) {
  return CouponRepository(
    firestore: ref.watch(firestoreDataSourceProvider),
    mock: ref.watch(mockApiDataSourceProvider),
  );
});

final promotionRepositoryProvider = Provider<PromotionRepository>((ref) {
  return PromotionRepository(
    mock: ref.watch(mockApiDataSourceProvider),
    firestore: ref.watch(firestoreDataSourceProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    remote: AuthRemoteDataSource(ref.watch(dioProvider)),
    mock: ref.watch(mockApiDataSourceProvider),
    firestore: ref.watch(firestoreDataSourceProvider),
  );
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(
    remote: AdminRemoteDataSource(ref.watch(dioProvider)),
    mock: ref.watch(mockApiDataSourceProvider),
    firestore: ref.watch(firestoreDataSourceProvider),
  );
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(
    remote: PaymentRemoteDataSource(ref.watch(dioProvider)),
    mock: ref.watch(mockApiDataSourceProvider),
  );
});

final productReviewRepositoryProvider = Provider<ProductReviewRepository>((ref) {
  return ProductReviewRepository(
    mock: ref.watch(mockApiDataSourceProvider),
    firestore: ref.watch(firestoreDataSourceProvider),
  );
});
