import 'package:easy_localization/easy_localization.dart';

/// Çeviri anahtarı varsa çevirir, admin tarafından girilen düz metni olduğu gibi döner.
String localizedOrRaw(String key) {
  if (key.startsWith('product_') ||
      key.startsWith('extra_') ||
      key.startsWith('auth_') ||
      key.startsWith('customer_') ||
      key.startsWith('campaign_') ||
      key.startsWith('option_') ||
      key.startsWith('portion_')) {
    return key.tr();
  }
  return key;
}
