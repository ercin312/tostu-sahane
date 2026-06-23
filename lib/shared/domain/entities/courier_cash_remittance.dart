import 'package:equatable/equatable.dart';

/// Kuryenin şube kasasına nakit/kapıda ödeme teslim bildirimi.
enum CourierCashRemittanceStatus { pending, approved, rejected }

class CourierCashRemittance extends Equatable {
  const CourierCashRemittance({
    required this.id,
    required this.courierId,
    required this.courierName,
    required this.branchId,
    required this.amount,
    required this.status,
    required this.requestedAt,
    this.reviewedAt,
    this.reviewedById,
    this.reviewedByName,
    this.rejectionReason,
    this.courierNote,
  });

  final String id;
  final String courierId;
  final String courierName;
  final String branchId;
  final double amount;
  final CourierCashRemittanceStatus status;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? reviewedById;
  final String? reviewedByName;
  final String? rejectionReason;
  final String? courierNote;

  bool get isPending => status == CourierCashRemittanceStatus.pending;

  CourierCashRemittance copyWith({
    CourierCashRemittanceStatus? status,
    DateTime? reviewedAt,
    String? reviewedById,
    String? reviewedByName,
    String? rejectionReason,
  }) {
    return CourierCashRemittance(
      id: id,
      courierId: courierId,
      courierName: courierName,
      branchId: branchId,
      amount: amount,
      status: status ?? this.status,
      requestedAt: requestedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedById: reviewedById ?? this.reviewedById,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      courierNote: courierNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'courier_id': courierId,
        'courier_name': courierName,
        'branch_id': branchId,
        'amount': amount,
        'status': status.name,
        'requested_at': requestedAt.toIso8601String(),
        'reviewed_at': reviewedAt?.toIso8601String(),
        'reviewed_by_id': reviewedById,
        'reviewed_by_name': reviewedByName,
        'rejection_reason': rejectionReason,
        'courier_note': courierNote,
      };

  factory CourierCashRemittance.fromJson(Map<String, dynamic> json) {
    return CourierCashRemittance(
      id: json['id'] as String,
      courierId: json['courier_id'] as String,
      courierName: json['courier_name'] as String? ?? '',
      branchId: json['branch_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      status: CourierCashRemittanceStatus.values.byName(
        json['status'] as String? ?? 'pending',
      ),
      requestedAt: DateTime.parse(json['requested_at'] as String),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      reviewedById: json['reviewed_by_id'] as String?,
      reviewedByName: json['reviewed_by_name'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      courierNote: json['courier_note'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        courierId,
        courierName,
        branchId,
        amount,
        status,
        requestedAt,
        reviewedAt,
        reviewedById,
        reviewedByName,
        rejectionReason,
        courierNote,
      ];
}
