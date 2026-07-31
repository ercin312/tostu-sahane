import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/features/waiter/domain/waiter_pos_catalog.dart';

void main() {
  test('tostlar has folders and direct leaves', () {
    final roots = WaiterPosCatalog.tostlar;
    final karisik = roots.firstWhere((n) => n.id == 'w_karisik');
    expect(karisik.isFolder, isTrue);
    expect(karisik.children, isNotEmpty);
    expect(karisik.children.every((c) => c.isLeaf), isTrue);

    final patso = roots.firstWhere((n) => n.id == 'w_patso');
    expect(patso.isLeaf, isTrue);
    expect(patso.price, 160);
  });

  test('icecekler and yan urunler are direct leaves', () {
    expect(WaiterPosCatalog.icecekler.every((n) => n.isLeaf), isTrue);
    expect(WaiterPosCatalog.yanUrunler.every((n) => n.isLeaf), isTrue);
    expect(
      WaiterPosCatalog.yanUrunler
          .firstWhere((n) => n.id == 'w_patates')
          .price,
      160,
    );
  });
}
