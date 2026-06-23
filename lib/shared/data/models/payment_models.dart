import '../../domain/entities/order.dart';

class PaytrInitRequest {
  const PaytrInitRequest({
    required this.merchantOid,
    required this.amount,
    required this.email,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.basketSummary,
    this.items = const [],
  });

  final String merchantOid;
  final double amount;
  final String email;
  final String customerName;
  final String phone;
  final String address;
  final String basketSummary;
  final List<CartItem> items;

  Map<String, dynamic> toJson() => {
        'merchant_oid': merchantOid,
        'amount': amount,
        'email': email,
        'customer_name': customerName,
        'phone': phone,
        'address': address,
        'basket_summary': basketSummary,
        'currency': 'TL',
        'iframe_v2': 1,
      };
}

class PaytrInitModel {
  const PaytrInitModel({
    required this.merchantOid,
    required this.iframeToken,
    required this.iframeUrl,
  });

  factory PaytrInitModel.fromJson(Map<String, dynamic> json) => PaytrInitModel(
        merchantOid: json['merchant_oid'] as String,
        iframeToken: json['iframe_token'] as String,
        iframeUrl: json['iframe_url'] as String? ??
            'https://www.paytr.com/odeme/guvenli/${json['iframe_token']}',
      );

  final String merchantOid;
  final String iframeToken;
  final String iframeUrl;
}

class PaytrVerifyModel {
  const PaytrVerifyModel({
    required this.merchantOid,
    required this.transactionId,
    required this.status,
  });

  factory PaytrVerifyModel.fromJson(Map<String, dynamic> json) =>
      PaytrVerifyModel(
        merchantOid: json['merchant_oid'] as String,
        transactionId: json['transaction_id'] as String,
        status: json['status'] as String,
      );

  final String merchantOid;
  final String transactionId;
  final String status;

  bool get isSuccess => status == 'success';
}
