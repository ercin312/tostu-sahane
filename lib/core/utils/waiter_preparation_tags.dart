import 'package:easy_localization/easy_localization.dart';

import '../localization/locale_keys.dart';

/// Garson iç sipariş hazırlık tercihleri (çoklu seçim).
abstract final class WaiterPreparationTags {
  static const mildSpicy = 'mild_spicy';
  static const spicy = 'spicy';
  static const lessCheese = 'less_cheese';
  static const noOil = 'no_oil';
  static const lessSauce = 'less_sauce';

  static const allKeys = [
    mildSpicy,
    spicy,
    lessCheese,
    noOil,
    lessSauce,
  ];

  static String labelKey(String tag) {
    return switch (tag) {
      mildSpicy => LocaleKeys.waiterPrepMildSpicy,
      spicy => LocaleKeys.waiterPrepSpicy,
      lessCheese => LocaleKeys.waiterPrepLessCheese,
      noOil => LocaleKeys.waiterPrepNoOil,
      lessSauce => LocaleKeys.waiterPrepLessSauce,
      _ => tag,
    };
  }

  static String label(String tag) => labelKey(tag).tr();

  static String joinLabels(Iterable<String> tags) {
    return tags.map(label).join(', ');
  }
}
