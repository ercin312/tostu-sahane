import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/utils/waiter_preparation_tags.dart';
import 'package:tostu_sahane/shared/domain/entities/waiter_preparation_option.dart';

void main() {
  final customOptions = [
    const WaiterPreparationOption(
      id: 'mild_spicy',
      labelTr: 'Az acılı',
      labelEn: 'Mild spicy',
    ),
    const WaiterPreparationOption(
      id: 'prep_123456',
      labelTr: 'Bol kaşar',
      labelEn: 'Extra cheese',
    ),
  ];

  test('resolves builtin and custom admin options to readable labels', () {
    final labels = WaiterPreparationTags.resolveLabels(
      ['mild_spicy', 'prep_123456'],
      options: customOptions,
    );
    expect(labels, ['Az acılı', 'Bol kaşar']);
  });

  test('does not treat unknown prep ids as translation keys', () {
    final label = WaiterPreparationTags.label(
      'prep_999',
      options: customOptions,
    );
    expect(label, 'prep_999');
    expect(label.contains('waiter_prep'), isFalse);
  });

  test('passes through already-resolved display text', () {
    expect(
      WaiterPreparationTags.label('Bol kaşar', options: customOptions),
      'Bol kaşar',
    );
  });

  test('falls back to turkish when english label is empty', () {
    const option = WaiterPreparationOption(
      id: 'prep_empty_en',
      labelTr: 'Susamsız',
      labelEn: '',
    );
    expect(
      WaiterPreparationTags.label('prep_empty_en', options: [option]),
      'Susamsız',
    );
  });
}
