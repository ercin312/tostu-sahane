import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../localization/locale_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

class DeliveryMapView extends StatelessWidget {
  const DeliveryMapView({
    super.key,
    required this.branchLat,
    required this.branchLng,
    required this.deliveryLat,
    required this.deliveryLng,
    this.height = 320,
  });

  final double branchLat;
  final double branchLng;
  final double deliveryLat;
  final double deliveryLng;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 3,
              child: CustomPaint(
                size: Size.infinite,
                painter: _DeliveryMapPainter(
                  branchLat: branchLat,
                  branchLng: branchLng,
                  deliveryLat: deliveryLat,
                  deliveryLng: deliveryLng,
                ),
              ),
            ),
            Positioned(
              left: AppSpacing.md,
              top: AppSpacing.md,
              child: _MapLegend(
                label: LocaleKeys.courierMapBranch.tr(),
                color: AppColors.primary,
                icon: Icons.store,
              ),
            ),
            Positioned(
              right: AppSpacing.md,
              bottom: AppSpacing.md,
              child: _MapLegend(
                label: LocaleKeys.courierMapDestination.tr(),
                color: AppColors.success,
                icon: Icons.location_on,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _DeliveryMapPainter extends CustomPainter {
  _DeliveryMapPainter({
    required this.branchLat,
    required this.branchLng,
    required this.deliveryLat,
    required this.deliveryLng,
  });

  final double branchLat;
  final double branchLng;
  final double deliveryLat;
  final double deliveryLng;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFE8F4EA);
    canvas.drawRect(Offset.zero & size, bg);

    _drawGrid(canvas, size);

    final branch = _project(branchLat, branchLng, size);
    final delivery = _project(deliveryLat, deliveryLng, size);

    final routePaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(branch.dx, branch.dy)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.25,
        delivery.dx,
        delivery.dy,
      );
    canvas.drawPath(path, routePaint);

    _drawMarker(canvas, branch, AppColors.primary);
    _drawMarker(canvas, delivery, AppColors.success);
  }

  Offset _project(double lat, double lng, Size size) {
    const minLat = 40.95;
    const maxLat = 41.08;
    const minLng = 28.95;
    const maxLng = 29.08;

    final x = ((lng - minLng) / (maxLng - minLng)).clamp(0.0, 1.0);
    final y = 1 - ((lat - minLat) / (maxLat - minLat)).clamp(0.0, 1.0);

    return Offset(
      size.width * (0.12 + x * 0.76),
      size.height * (0.12 + y * 0.76),
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    const step = 32.0;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _drawMarker(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(
      center,
      18,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      18,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      center,
      6,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _DeliveryMapPainter oldDelegate) {
    return branchLat != oldDelegate.branchLat ||
        branchLng != oldDelegate.branchLng ||
        deliveryLat != oldDelegate.deliveryLat ||
        deliveryLng != oldDelegate.deliveryLng;
  }
}

double estimateRouteKm(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const earthRadiusKm = 6371.0;
  final dLat = _toRad(lat2 - lat1);
  final dLng = _toRad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRad(lat1)) *
          math.cos(_toRad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _toRad(double deg) => deg * math.pi / 180;
