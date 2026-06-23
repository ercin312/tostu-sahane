import 'package:equatable/equatable.dart';

class ProductExtra extends Equatable {
  const ProductExtra({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
  });

  final String id;
  final String name;
  final double price;
  final String? imageUrl;

  ProductExtra copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
  }) {
    return ProductExtra(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'image_url': imageUrl,
      };

  factory ProductExtra.fromJson(Map<String, dynamic> json) {
    return ProductExtra(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, price, imageUrl];
}
