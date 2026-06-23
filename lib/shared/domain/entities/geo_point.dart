import 'package:equatable/equatable.dart';

/// WGS84 koordinat noktası (domain katmanı).
class GeoPoint extends Equatable {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  GeoPoint copyWith({double? latitude, double? longitude}) {
    return GeoPoint(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
      };

  factory GeoPoint.fromJson(Map<String, dynamic> json) => GeoPoint(
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
      );

  @override
  List<Object?> get props => [latitude, longitude];
}

/// Teslimat bölgesi modu.
/// [radius] — Yemek Sepeti tarzı kuş uçuşu mesafe (km).
/// [polygon] — Harita üzerinde çizilen alan.
enum DeliveryZoneMode { radius, polygon }
