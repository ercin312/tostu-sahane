import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';

import '../../shared/domain/entities/waiter_mode_settings.dart';
import '../../shared/domain/entities/waiter_preparation_option.dart';
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

  static String? _builtinLocaleKey(String tag) {
    return switch (tag) {
      mildSpicy => LocaleKeys.waiterPrepMildSpicy,
      spicy => LocaleKeys.waiterPrepSpicy,
      lessCheese => LocaleKeys.waiterPrepLessCheese,
      noOil => LocaleKeys.waiterPrepNoOil,
      lessSauce => LocaleKeys.waiterPrepLessSauce,
      _ => null,
    };
  }

  /// Siparişe / mutfağa yazılacak okunabilir etiketler (Türkçe öncelikli).
  static List<String> resolveLabels(
    Iterable<String> tags, {
    List<WaiterPreparationOption>? options,
  }) {
    return tags
        .map((t) => label(t, options: options, preferTurkish: true))
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  static String label(
    String tag, {
    List<WaiterPreparationOption>? options,
    bool preferTurkish = false,
  }) {
    final trimmed = tag.trim();
    if (trimmed.isEmpty) return '';

    final catalog = options ?? WaiterModeSettings.defaultPreparationOptions;
    for (final option in catalog) {
      if (option.id == trimmed) {
        return _displayFromOption(option, preferTurkish: preferTurkish);
      }
    }

    if (preferTurkish) {
      for (final option in WaiterModeSettings.defaultPreparationOptions) {
        if (option.id == trimmed && option.labelTr.trim().isNotEmpty) {
          return option.labelTr.trim();
        }
      }
    }

    final builtin = _builtinLocaleKey(trimmed);
    if (builtin != null) return builtin.tr();

    // Zaten okunabilir metin saklanmış veya bilinmeyen id.
    // `prep_…` id'lerini çeviri anahtarı sanmayız.
    return trimmed;
  }

  static String joinLabels(
    Iterable<String> tags, {
    List<WaiterPreparationOption>? options,
  }) {
    return tags.map((t) => label(t, options: options)).join(', ');
  }

  static String _displayFromOption(
    WaiterPreparationOption option, {
    bool preferTurkish = false,
  }) {
    final tr = option.labelTr.trim();
    final en = option.labelEn.trim();

    if (preferTurkish || _isTurkishLocale()) {
      if (tr.isNotEmpty) return tr;
      if (en.isNotEmpty) return en;
    } else {
      if (en.isNotEmpty) return en;
      if (tr.isNotEmpty) return tr;
    }
    return option.id;
  }

  static bool _isTurkishLocale() {
    final code = Intl.getCurrentLocale();
    if (code.isEmpty) return true;
    return code.startsWith('tr');
  }
}
