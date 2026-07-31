import 'dart:ui';

import 'kitchen_timeline_layout.dart';

/// 24" mutfak paneli dikey (saat yönünde döndürülmüş) kullanım düzeni.
abstract final class KitchenDisplayLayout {
  /// Yükseklik > genişlik → Windows ekran döndürmesi / dikey panel.
  static bool isPortraitKitchenDisplay(Size size) => size.height > size.width;

  static int columnCount(Size size) {
    if (isPortraitKitchenDisplay(size)) return 1;
    return KitchenTimelineLayout.columnCountForWidth(size.width);
  }

  /// Tam genişlik fişlerde uzaktan okunabilirlik.
  static double typeScale(Size size) =>
      isPortraitKitchenDisplay(size) ? 1.12 : 1.0;

  static double horizontalPadding(Size size) =>
      isPortraitKitchenDisplay(size) ? 14.0 : 10.0;

  static double actionIconSize(Size size) =>
      isPortraitKitchenDisplay(size) ? 32.0 : 26.0;

  static double actionButtonMinSize(Size size) =>
      isPortraitKitchenDisplay(size) ? 52.0 : 40.0;
}

/// Mutfak fişi tipografi — [scale] dikey ekranda büyütülür.
class KitchenTicketMetrics {
  const KitchenTicketMetrics({this.scale = 1.0});

  factory KitchenTicketMetrics.forSize(Size size) => KitchenTicketMetrics(
        scale: KitchenDisplayLayout.typeScale(size),
      );

  final double scale;

  double get tableNumber => 34.0 * scale;
  double get orderNumber => 20.0 * scale;
  double get meta => 16.0 * scale;
  double get prepTag => 20.0 * scale;
  double get orderNote => 18.0 * scale;
  double get itemQty => 24.0 * scale;
  double get itemTitle => 26.0 * scale;
  double get itemDetail => 18.0 * scale;
  double get itemNote => 18.0 * scale;
}
