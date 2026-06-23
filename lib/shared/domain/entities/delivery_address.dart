import 'package:equatable/equatable.dart';

class DeliveryAddress extends Equatable {
  const DeliveryAddress({
    required this.id,
    required this.title,
    required this.fullAddress,
    this.note,
    this.isDefault = false,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String title;
  final String fullAddress;
  final String? note;
  final bool isDefault;
  final double? latitude;
  final double? longitude;

  DeliveryAddress copyWith({
    String? title,
    String? fullAddress,
    String? note,
    bool? isDefault,
    double? latitude,
    double? longitude,
  }) {
    return DeliveryAddress(
      id: id,
      title: title ?? this.title,
      fullAddress: fullAddress ?? this.fullAddress,
      note: note ?? this.note,
      isDefault: isDefault ?? this.isDefault,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'full_address': fullAddress,
        'note': note,
        'is_default': isDefault,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory DeliveryAddress.fromJson(Map<String, dynamic> json) {
    return DeliveryAddress(
      id: json['id'] as String,
      title: json['title'] as String,
      fullAddress: json['full_address'] as String,
      note: json['note'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  @override
  List<Object?> get props =>
      [id, title, fullAddress, note, isDefault, latitude, longitude];
}
