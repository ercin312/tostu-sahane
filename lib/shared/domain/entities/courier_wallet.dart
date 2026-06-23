import 'package:equatable/equatable.dart';

import 'courier_cash_remittance.dart';

enum CourierWalletEntryType { delivery, payout }

enum CourierWalletPaymentKind { cash, card, online, payout }

class CourierWalletEntry extends Equatable {
  const CourierWalletEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.createdAt,
    this.orderNumber,
    this.paymentKind,
    this.note,
    this.remittanceStatus,
  });

  final String id;
  final CourierWalletEntryType type;
  final double amount;
  final DateTime createdAt;
  final int? orderNumber;
  final CourierWalletPaymentKind? paymentKind;
  final String? note;
  final CourierCashRemittanceStatus? remittanceStatus;

  @override
  List<Object?> get props => [
        id,
        type,
        amount,
        createdAt,
        orderNumber,
        paymentKind,
        note,
        remittanceStatus,
      ];
}

class CourierWalletSummary extends Equatable {
  const CourierWalletSummary({
    required this.todayDeliveries,
    required this.todayCash,
    required this.todayCard,
    required this.availableBalance,
    required this.pendingPayout,
    required this.totalEarned,
    this.approvedRemitted = 0,
  });

  final int todayDeliveries;
  final double todayCash;
  final double todayCard;
  final double availableBalance;
  final double pendingPayout;
  final double totalEarned;
  final double approvedRemitted;

  @override
  List<Object?> get props => [
        todayDeliveries,
        todayCash,
        todayCard,
        availableBalance,
        pendingPayout,
        totalEarned,
        approvedRemitted,
      ];
}
