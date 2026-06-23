import 'package:equatable/equatable.dart';

class ProductReview extends Equatable {
  const ProductReview({
    required this.id,
    required this.productId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.orderId,
    this.isApproved = false,
  });

  final String id;
  final String productId;
  final String? orderId;
  final String customerId;
  final String customerName;
  final int rating;
  final String comment;
  final DateTime createdAt;
  final bool isApproved;

  ProductReview copyWith({
    String? id,
    String? productId,
    String? customerId,
    String? customerName,
    int? rating,
    String? comment,
    DateTime? createdAt,
    String? orderId,
    bool? isApproved,
  }) {
    return ProductReview(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      orderId: orderId ?? this.orderId,
      isApproved: isApproved ?? this.isApproved,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        orderId,
        customerId,
        customerName,
        rating,
        comment,
        createdAt,
        isApproved,
      ];
}
