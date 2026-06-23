import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/core/utils/waiter_order_notes.dart';
import 'package:tostu_sahane/core/utils/waiter_preparation_tags.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';

void main() {
  group('WaiterOrderNotes', () {
    test('build merges text and preparation tags', () {
      final note = WaiterOrderNotes.build(
        textNote: 'Az tuzlu',
        preparationTags: const [
          WaiterPreparationTags.spicy,
          WaiterPreparationTags.lessCheese,
        ],
      );
      expect(note, contains('Az tuzlu'));
      expect(note!.split('\n').length, 2);
    });

    test('display combines separate text note and preparation tags', () {
      final order = Order(
        id: 'o2',
        orderNumber: 2,
        customerId: 'w1',
        customerName: 'Masa 5',
        branchId: 'b1',
        items: const [],
        totalAmount: 0,
        status: OrderStatus.preparing,
        createdAt: DateTime(2026),
        address: 'Salon',
        paymentMethod: PaymentMethod.cashOnDelivery,
        orderType: OrderType.dineIn,
        tableNumber: 5,
        orderNote: 'Az tuzlu',
        preparationTags: const [
          WaiterPreparationTags.spicy,
          WaiterPreparationTags.lessCheese,
        ],
      );
      final display = WaiterOrderNotes.display(order)!;
      expect(display, contains('Az tuzlu'));
      expect(display, contains('\n'));
    });

    test('display falls back to legacy preparation tags', () {
      final order = Order(
        id: 'o1',
        orderNumber: 1,
        customerId: 'w1',
        customerName: 'Masa 3',
        branchId: 'b1',
        items: const [],
        totalAmount: 0,
        status: OrderStatus.preparing,
        createdAt: DateTime(2026),
        address: 'Salon',
        paymentMethod: PaymentMethod.cashOnDelivery,
        orderType: OrderType.dineIn,
        tableNumber: 3,
        preparationTags: const [WaiterPreparationTags.noOil],
      );
      expect(WaiterOrderNotes.hasNote(order), isTrue);
      expect(WaiterOrderNotes.display(order), isNotEmpty);
    });

    test('mergePreferRicher keeps longest note', () {
      expect(
        WaiterOrderNotes.mergePreferRicher(
          'Acılı',
          'Acılı\nAz kaşarlı',
          null,
        ),
        'Acılı\nAz kaşarlı',
      );
    });
  });
}
