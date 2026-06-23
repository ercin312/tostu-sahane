import '../../../core/config/app_config.dart';
import '../../domain/entities/operational_purge_result.dart';
import '../datasources/firestore/firestore_datasource.dart';
import '../datasources/local/local_datasources.dart';
import '../datasources/mock_api_datasource.dart';

enum OperationalPurgeScope { all, courier, branch }

class OperationalDataPurgeRepository {
  OperationalDataPurgeRepository({
    required FirestoreDataSource firestore,
    required MockApiDataSource mock,
    required OrderLocalDataSource orderLocal,
    required CourierCashRemittanceLocalDataSource remittanceLocal,
  })  : _firestore = firestore,
        _mock = mock,
        _orderLocal = orderLocal,
        _remittanceLocal = remittanceLocal;

  final FirestoreDataSource _firestore;
  final MockApiDataSource _mock;
  final OrderLocalDataSource _orderLocal;
  final CourierCashRemittanceLocalDataSource _remittanceLocal;

  Future<OperationalPurgeResult> purgeAllReportData() {
    return _purge(scope: OperationalPurgeScope.all);
  }

  Future<OperationalPurgeResult> purgeCourierData(String courierId) {
    return _purge(scope: OperationalPurgeScope.courier, courierId: courierId);
  }

  Future<OperationalPurgeResult> purgeBranchData(String branchId) {
    return _purge(scope: OperationalPurgeScope.branch, branchId: branchId);
  }

  Future<OperationalPurgeResult> _purge({
    required OperationalPurgeScope scope,
    String? courierId,
    String? branchId,
  }) async {
    final isAll = scope == OperationalPurgeScope.all;
    final scopedCourierId =
        scope == OperationalPurgeScope.courier ? courierId : null;
    final scopedBranchId =
        scope == OperationalPurgeScope.branch ? branchId : null;

    var ordersDeleted = 0;
    var reviewsDeleted = 0;
    var remittancesDeleted = 0;

    if (AppConfig.useFirestore) {
      final orderIds = isAll
          ? null
          : await _firestore.collectOrderIds(
              courierId: scopedCourierId,
              branchId: scopedBranchId,
            );

      ordersDeleted = await _firestore.deleteOrders(
        courierId: scopedCourierId,
        branchId: scopedBranchId,
        resetCounterWhenAll: isAll,
      );
      reviewsDeleted = await _firestore.deleteAllProductReviews(
        orderIds: isAll ? null : orderIds,
      );
      remittancesDeleted = await _firestore.deleteCashRemittances(
        courierId: scopedCourierId,
        branchId: scopedBranchId,
      );
    } else if (AppConfig.useMockApi) {
      final orderIds = _mock.collectOrderIds(
        courierId: scopedCourierId,
        branchId: scopedBranchId,
      );
      ordersDeleted = _mock.purgeOrders(
        courierId: scopedCourierId,
        branchId: scopedBranchId,
      );
      reviewsDeleted = _mock.purgeProductReviews(
        orderIds: isAll ? null : orderIds,
      );
      remittancesDeleted = await _remittanceLocal.purge(
        courierId: scopedCourierId,
        branchId: scopedBranchId,
      );
    }

    if (AppConfig.useFirestore && AppConfig.useMockApi) {
      final orderIds = _mock.collectOrderIds(
        courierId: scopedCourierId,
        branchId: scopedBranchId,
      );
      _mock.purgeOrders(
        courierId: scopedCourierId,
        branchId: scopedBranchId,
      );
      _mock.purgeProductReviews(orderIds: isAll ? null : orderIds);
    }

    if (AppConfig.useFirestore) {
      await _remittanceLocal.purge(
        courierId: scopedCourierId,
        branchId: scopedBranchId,
      );
    }

    await _purgeLocalOrders(
      courierId: scopedCourierId,
      branchId: scopedBranchId,
      clearAll: isAll,
    );

    return OperationalPurgeResult(
      ordersDeleted: ordersDeleted,
      reviewsDeleted: reviewsDeleted,
      remittancesDeleted: remittancesDeleted,
    );
  }

  Future<void> _purgeLocalOrders({
    String? courierId,
    String? branchId,
    required bool clearAll,
  }) async {
    if (clearAll) {
      await _orderLocal.clearOrders();
      return;
    }
    final orders = await _orderLocal.loadOrders();
    final remaining = orders.where((order) {
      if (courierId != null && order.courierId == courierId) return false;
      if (branchId != null && order.branchId == branchId) return false;
      return true;
    }).toList();
    await _orderLocal.saveOrders(remaining);
  }
}
