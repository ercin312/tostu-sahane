import 'package:equatable/equatable.dart';

import 'product_extra.dart';
import 'product_combo_item.dart';

enum ProductCategory { all, tost, sahanda, drink, snack, combo }

class Product extends Equatable {
  const Product({
    required this.id,
    required this.nameKey,
    required this.descriptionKey,
    required this.price,
    required this.category,
    this.isAvailable = true,
    this.imageColorValue = 0xFFFFE0E6,
    this.imageUrl,
    this.extras = const [],
    this.extraIds = const [],
    this.isCombo = false,
    this.comboItems = const [],
    this.isRecommended = false,
  });

  final String id;
  final String nameKey;
  final String descriptionKey;
  final double price;
  final ProductCategory category;
  final bool isAvailable;
  final int imageColorValue;
  final String? imageUrl;
  final List<ProductExtra> extras;
  final List<String> extraIds;
  final bool isCombo;
  final List<ProductComboItem> comboItems;
  final bool isRecommended;

  Product copyWith({
    String? id,
    String? nameKey,
    String? descriptionKey,
    double? price,
    ProductCategory? category,
    bool? isAvailable,
    int? imageColorValue,
    String? imageUrl,
    List<ProductExtra>? extras,
    List<String>? extraIds,
    bool? isCombo,
    List<ProductComboItem>? comboItems,
    bool? isRecommended,
  }) {
    return Product(
      id: id ?? this.id,
      nameKey: nameKey ?? this.nameKey,
      descriptionKey: descriptionKey ?? this.descriptionKey,
      price: price ?? this.price,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      imageColorValue: imageColorValue ?? this.imageColorValue,
      imageUrl: imageUrl ?? this.imageUrl,
      extras: extras ?? this.extras,
      extraIds: extraIds ?? this.extraIds,
      isCombo: isCombo ?? this.isCombo,
      comboItems: comboItems ?? this.comboItems,
      isRecommended: isRecommended ?? this.isRecommended,
    );
  }

  @override
  List<Object?> get props => [
        id,
        nameKey,
        descriptionKey,
        price,
        category,
        isAvailable,
        imageUrl,
        extras,
        extraIds,
        isCombo,
        comboItems,
        isRecommended,
      ];
}
