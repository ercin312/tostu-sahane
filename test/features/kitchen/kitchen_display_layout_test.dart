import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/features/kitchen/presentation/utils/kitchen_display_layout.dart';

void main() {
  test('portrait 24 inch panel uses single column', () {
    const portrait = Size(1080, 1920);
    expect(KitchenDisplayLayout.isPortraitKitchenDisplay(portrait), isTrue);
    expect(KitchenDisplayLayout.columnCount(portrait), 1);
    expect(KitchenDisplayLayout.typeScale(portrait), greaterThan(1.0));
  });

  test('landscape wide panel keeps multi-column thresholds', () {
    const landscape = Size(1920, 1080);
    expect(KitchenDisplayLayout.isPortraitKitchenDisplay(landscape), isFalse);
    expect(KitchenDisplayLayout.columnCount(landscape), 3);
    expect(KitchenDisplayLayout.typeScale(landscape), 1.0);
  });
}
