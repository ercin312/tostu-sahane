import 'package:equatable/equatable.dart';

class ProductComboItem extends Equatable {
  const ProductComboItem({
    required this.productId,
    required this.nameKey,
    this.quantity = 1,
  });

  final String productId;
  final String nameKey;
  final int quantity;

  ProductComboItem copyWith({
    String? productId,
    String? nameKey,
    int? quantity,
  }) {
    return ProductComboItem(
      productId: productId ?? this.productId,
      nameKey: nameKey ?? this.nameKey,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'name_key': nameKey,
        'quantity': quantity,
      };

  factory ProductComboItem.fromJson(Map<String, dynamic> json) {
    return ProductComboItem(
      productId: json['product_id'] as String,
      nameKey: json['name_key'] as String,
      quantity: json['quantity'] as int? ?? 1,
    );
  }

  @override
  List<Object?> get props => [productId, nameKey, quantity];
}
