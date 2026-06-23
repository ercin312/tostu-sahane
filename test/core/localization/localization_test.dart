import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tostu_sahane/core/localization/locale_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Localization', () {
    test('locale keys match translation file keys', () async {
      final jsonString =
          await rootBundle.loadString('assets/translations/tr-TR.json');
      final translations = json.decode(jsonString) as Map<String, dynamic>;

      expect(translations[LocaleKeys.appName], 'Tostu Şahane');
      expect(translations[LocaleKeys.checkoutButtonText], 'Sipariş Ver');
      expect(translations[LocaleKeys.settingsLanguage], 'Dil');
    });

    test('en-US translation file contains matching keys', () async {
      final trJson =
          await rootBundle.loadString('assets/translations/tr-TR.json');
      final enJson =
          await rootBundle.loadString('assets/translations/en-US.json');

      final trKeys = (json.decode(trJson) as Map<String, dynamic>).keys;
      final enKeys = (json.decode(enJson) as Map<String, dynamic>).keys;

      expect(enKeys, containsAll(trKeys));
    });
  });
}
