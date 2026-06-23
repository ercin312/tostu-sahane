import 'localized_text.dart';

/// Fişte gösterilecek garson kodu: kullanıcı adı veya adın ilk 2 harfi.
String waiterReceiptCode({String? username, String? name}) {
  final login = username?.trim();
  if (login != null && login.isNotEmpty) return login;

  final display = localizedOrRaw(name ?? '').trim();
  if (display.isEmpty) return '—';

  final firstWord = display.split(RegExp(r'\s+')).firstWhere(
        (part) => part.isNotEmpty,
        orElse: () => display,
      );
  if (firstWord.length >= 2) {
    return firstWord.substring(0, 2).toUpperCase();
  }
  return firstWord.toUpperCase();
}
