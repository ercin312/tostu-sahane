import 'dart:async';

import '../../../core/config/app_config.dart';
import '../../domain/entities/courier_cash_remittance.dart';
import '../datasources/firestore/firestore_datasource.dart';
import '../datasources/local/local_datasources.dart';

class CourierCashRemittanceRepository {
  CourierCashRemittanceRepository({
    required FirestoreDataSource firestore,
    required CourierCashRemittanceLocalDataSource local,
  })  : _firestore = firestore,
        _local = local;

  final FirestoreDataSource _firestore;
  final CourierCashRemittanceLocalDataSource _local;
  final _localEvents = StreamController<void>.broadcast();

  Stream<void> get _changes => _localEvents.stream;

  Future<List<CourierCashRemittance>> getForCourier(String courierId) async {
    if (AppConfig.useFirestore) {
      return _firestore.getCashRemittances(courierId: courierId);
    }
    final all = await _local.loadAll();
    return all.where((r) => r.courierId == courierId).toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  Future<List<CourierCashRemittance>> getForBranch(String branchId) async {
    if (AppConfig.useFirestore) {
      return _firestore.getCashRemittances(branchId: branchId);
    }
    final all = await _local.loadAll();
    return all.where((r) => r.branchId == branchId).toList()
      ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  Future<List<CourierCashRemittance>> getAll() async {
    if (AppConfig.useFirestore) {
      return _firestore.getCashRemittances();
    }
    final all = await _local.loadAll();
    return all..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
  }

  Stream<List<CourierCashRemittance>> watchForCourier(String courierId) {
    if (AppConfig.useFirestore) {
      return _firestore.watchCashRemittances(courierId: courierId);
    }
    return _changes.asyncMap((_) => getForCourier(courierId));
  }

  Stream<List<CourierCashRemittance>> watchForBranch(String branchId) {
    if (AppConfig.useFirestore) {
      return _firestore.watchCashRemittances(branchId: branchId);
    }
    return _changes.asyncMap((_) => getForBranch(branchId));
  }

  Stream<List<CourierCashRemittance>> watchAll() {
    if (AppConfig.useFirestore) {
      return _firestore.watchCashRemittances();
    }
    return _changes.asyncMap((_) => getAll());
  }

  Future<CourierCashRemittance> requestRemittance({
    required String courierId,
    required String courierName,
    required String branchId,
    required double amount,
    String? courierNote,
  }) async {
    final existing = await getForCourier(courierId);
    if (existing.any((r) => r.isPending)) {
      throw CourierRemittanceException('courier_remittance_pending_exists');
    }

    final remittance = CourierCashRemittance(
      id: 'rem_${DateTime.now().millisecondsSinceEpoch}',
      courierId: courierId,
      courierName: courierName,
      branchId: branchId,
      amount: amount,
      status: CourierCashRemittanceStatus.pending,
      requestedAt: DateTime.now(),
      courierNote: courierNote,
    );

    if (AppConfig.useFirestore) {
      return _firestore.createCashRemittance(remittance);
    }

    final all = await _local.loadAll();
    await _local.saveAll([remittance, ...all]);
    _localEvents.add(null);
    return remittance;
  }

  Future<CourierCashRemittance> approve({
    required String remittanceId,
    required String reviewerId,
    required String reviewerName,
  }) {
    return _review(
      remittanceId: remittanceId,
      status: CourierCashRemittanceStatus.approved,
      reviewerId: reviewerId,
      reviewerName: reviewerName,
    );
  }

  Future<CourierCashRemittance> reject({
    required String remittanceId,
    required String reviewerId,
    required String reviewerName,
    String? rejectionReason,
  }) {
    return _review(
      remittanceId: remittanceId,
      status: CourierCashRemittanceStatus.rejected,
      reviewerId: reviewerId,
      reviewerName: reviewerName,
      rejectionReason: rejectionReason,
    );
  }

  Future<CourierCashRemittance> _review({
    required String remittanceId,
    required CourierCashRemittanceStatus status,
    required String reviewerId,
    required String reviewerName,
    String? rejectionReason,
  }) async {
    if (AppConfig.useFirestore) {
      return _firestore.reviewCashRemittance(
        remittanceId: remittanceId,
        status: status,
        reviewerId: reviewerId,
        reviewerName: reviewerName,
        rejectionReason: rejectionReason,
      );
    }

    final all = await _local.loadAll();
    final index = all.indexWhere((r) => r.id == remittanceId);
    if (index < 0) {
      throw CourierRemittanceException('common_error');
    }
    final updated = all[index].copyWith(
      status: status,
      reviewedAt: DateTime.now(),
      reviewedById: reviewerId,
      reviewedByName: reviewerName,
      rejectionReason: rejectionReason,
    );
    all[index] = updated;
    await _local.saveAll(all);
    _localEvents.add(null);
    return updated;
  }
}

class CourierRemittanceException implements Exception {
  const CourierRemittanceException(this.messageKey);
  final String messageKey;
}
