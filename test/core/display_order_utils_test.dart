import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/core/utils/display_order_utils.dart';

class _Item {
  const _Item(this.id, this.name);
  final String id;
  final String name;
}

void main() {
  group('sortByDisplayOrder', () {
    test('orders by display list', () {
      final items = [
        const _Item('c', 'C'),
        const _Item('a', 'A'),
        const _Item('b', 'B'),
      ];
      final sorted = sortByDisplayOrder(
        items: items,
        displayOrder: const ['b', 'a'],
        idFor: (i) => i.id,
        tieBreaker: (a, b) => a.name.compareTo(b.name),
      );
      expect(sorted.map((e) => e.id).toList(), ['b', 'a', 'c']);
    });
  });
}
