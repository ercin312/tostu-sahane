import 'package:equatable/equatable.dart';

enum ProductExtraKind {
  /// İçecek / yanında giden ürün.
  addon,
  /// Tosta eklenebilen extra malzeme (kaşar, sucuk vb.).
  ingredient,
}

extension ProductExtraKindX on ProductExtraKind {
  String get storageValue => name;

  static ProductExtraKind parse(Object? raw) {
    final value = raw?.toString();
    if (value == ProductExtraKind.ingredient.name) {
      return ProductExtraKind.ingredient;
    }
    return ProductExtraKind.addon;
  }
}

class ProductExtra extends Equatable {
  const ProductExtra({
    required this.id,
    required this.name,
    required this.price,
    this.imageUrl,
    this.kind = ProductExtraKind.addon,
  });

  final String id;
  final String name;
  final double price;
  final String? imageUrl;
  final ProductExtraKind kind;

  bool get isToastIngredient => kind == ProductExtraKind.ingredient;

  ProductExtra copyWith({
    String? id,
    String? name,
    double? price,
    String? imageUrl,
    ProductExtraKind? kind,
  }) {
    return ProductExtra(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      kind: kind ?? this.kind,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'image_url': imageUrl,
        'kind': kind.name,
      };

  factory ProductExtra.fromJson(Map<String, dynamic> json) {
    return ProductExtra(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      imageUrl: json['image_url'] as String?,
      kind: ProductExtraKindX.parse(json['kind']),
    );
  }

  @override
  List<Object?> get props => [id, name, price, imageUrl, kind];
}
