import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/features/waiter/domain/waiter_pos_catalog.dart';
import 'package:tostu_sahane/shared/domain/entities/waiter_mode_settings.dart';

void main() {
  test('WaiterModeSettings round-trip includes new fields', () {
    const settings = WaiterModeSettings(
      preparationOptions: WaiterModeSettings.defaultPreparationOptions,
      productDisplayOrder: ['p1', 'p2'],
      catalogExtraDisplayOrder: ['e1'],
      posCatalog: {
        'yanUrunler': [
          WaiterPosNode(id: 'w_sos', label: 'SOS', price: 10),
        ],
      },
    );
    final json = settings.toJson();
    final restored = WaiterModeSettings.fromJson(json);
    expect(restored.productDisplayOrder, ['p1', 'p2']);
    expect(restored.catalogExtraDisplayOrder, ['e1']);
    expect(restored.preparationOptions.length, 5);
    expect(restored.preparationOptions.first.id, 'mild_spicy');
    expect(restored.posCatalog['yanUrunler']!.single.label, 'SOS');
  });
}
