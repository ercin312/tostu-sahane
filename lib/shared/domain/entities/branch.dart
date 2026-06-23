import 'package:equatable/equatable.dart';

import 'geo_point.dart';
import '../../../core/utils/branch_hours_utils.dart';

class Branch extends Equatable {
  const Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.distanceKm = 0,
    this.deliveryZoneMode = DeliveryZoneMode.radius,
    this.deliveryRadiusKm = 3.0,
    this.deliveryPolygon = const [],
    this.openTime = '09:00',
    this.closeTime = '23:00',
    this.baseDeliveryFee = 15.0,
    this.freeDeliveryMinOrder = 150.0,
    this.deliveryFeePerKm = 5.0,
    this.prepTimeMinutes = 15,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final DeliveryZoneMode deliveryZoneMode;
  /// Kuş uçuşu km — [DeliveryZoneMode.radius] modunda kullanılır.
  final double deliveryRadiusKm;
  /// Harita üzerinde çizilen köşe noktaları — [DeliveryZoneMode.polygon] modunda.
  final List<GeoPoint> deliveryPolygon;
  /// Çalışma saati başlangıcı "HH:mm"
  final String openTime;
  /// Çalışma saati bitişi "HH:mm"
  final String closeTime;
  /// Sabit teslimat ücreti (TL)
  final double baseDeliveryFee;
  /// Bu tutarın üzerinde ücretsiz teslimat
  final double freeDeliveryMinOrder;
  /// Km başına ek ücret (TL)
  final double deliveryFeePerKm;
  /// Ortalama hazırlık süresi (dakika)
  final int prepTimeMinutes;

  bool get isOpenNow => BranchHoursUtils.isOpenNow(
        openTime: openTime,
        closeTime: closeTime,
      );

  bool isOpenAt(DateTime at) => BranchHoursUtils.isOpenNow(
        openTime: openTime,
        closeTime: closeTime,
        at: at,
      );

  bool isValidScheduledDelivery(
    DateTime scheduledAt, {
    DateTime? now,
    Duration minLeadTime = const Duration(minutes: 30),
  }) =>
      BranchHoursUtils.isValidScheduledDelivery(
        scheduledAt: scheduledAt,
        openTime: openTime,
        closeTime: closeTime,
        now: now,
        minLeadTime: minLeadTime,
      );

  String get hoursLabel =>
      BranchHoursUtils.formatRange(openTime, closeTime);

  Branch copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    double? distanceKm,
    DeliveryZoneMode? deliveryZoneMode,
    double? deliveryRadiusKm,
    List<GeoPoint>? deliveryPolygon,
    String? openTime,
    String? closeTime,
    double? baseDeliveryFee,
    double? freeDeliveryMinOrder,
    double? deliveryFeePerKm,
    int? prepTimeMinutes,
  }) {
    return Branch(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm ?? this.distanceKm,
      deliveryZoneMode: deliveryZoneMode ?? this.deliveryZoneMode,
      deliveryRadiusKm: deliveryRadiusKm ?? this.deliveryRadiusKm,
      deliveryPolygon: deliveryPolygon ?? this.deliveryPolygon,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      baseDeliveryFee: baseDeliveryFee ?? this.baseDeliveryFee,
      freeDeliveryMinOrder: freeDeliveryMinOrder ?? this.freeDeliveryMinOrder,
      deliveryFeePerKm: deliveryFeePerKm ?? this.deliveryFeePerKm,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        address,
        latitude,
        longitude,
        distanceKm,
        deliveryZoneMode,
        deliveryRadiusKm,
        deliveryPolygon,
        openTime,
        closeTime,
        baseDeliveryFee,
        freeDeliveryMinOrder,
        deliveryFeePerKm,
        prepTimeMinutes,
      ];
}
