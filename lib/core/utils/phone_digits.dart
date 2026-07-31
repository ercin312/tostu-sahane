/// Türkiye telefon numarasını karşılaştırmak için 10 haneye indirir.
/// Örn: +90 555 123 45 67 / 0555… / 555… → `5551234567`
String? normalizeTrPhoneDigits(String? raw) {
  var d = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('90') && d.length >= 12) {
    d = d.substring(2);
  }
  if (d.startsWith('0') && d.length >= 11) {
    d = d.substring(1);
  }
  if (d.length == 10) return d;
  // 10'dan uzunsa son 10 hane (ülke kodu artığı)
  if (d.length > 10) return d.substring(d.length - 10);
  return null;
}

/// İki telefon aynı TR aboneyi mi işaret ediyor?
bool trPhonesMatch(String? a, String? b) {
  final na = normalizeTrPhoneDigits(a);
  final nb = normalizeTrPhoneDigits(b);
  if (na == null || nb == null) return false;
  return na == nb;
}
