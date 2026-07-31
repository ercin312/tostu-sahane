import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../shared/domain/entities/order.dart';
import 'phone_digits.dart';

/// Oturumdaki müşteri için olası `customer_id` değerleri (format farkları).
Set<String> customerIdentityKeys(AuthState auth) {
  final keys = <String>{auth.user.id.trim()};
  final ten = normalizeTrPhoneDigits(auth.phone);
  if (ten != null) {
    keys.add('customer_$ten');
    keys.add('phone_$ten');
    keys.add('customer_0$ten');
    keys.add('0$ten');
    keys.add(ten);
    keys.add('customer_+90$ten');
    keys.add('customer_90$ten');
  }
  final phoneDigits = auth.phone.replaceAll(RegExp(r'\D'), '');
  if (phoneDigits.isNotEmpty) {
    keys.add('customer_$phoneDigits');
    keys.add('phone_$phoneDigits');
    if (auth.phone.trim().isNotEmpty) {
      keys.add('customer_${auth.phone.trim()}');
    }
  }
  final email = auth.email?.trim().toLowerCase();
  if (email != null && email.isNotEmpty) {
    keys.add('customer_$email');
  }
  return keys;
}

/// Telefon/e-posta format farklarından kaynaklanan customerId uyumsuzluklarını tolere eder.
bool orderBelongsToCustomer(Order order, AuthState auth) {
  if (order.phoneFailed) return false;
  if (!order.isDelivery) return false;

  final keys = customerIdentityKeys(auth);
  if (keys.contains(order.customerId)) return true;

  final authTen = normalizeTrPhoneDigits(auth.phone);
  if (authTen != null) {
    final cid = order.customerId;
    if (cid.endsWith(authTen) || cid.contains(authTen)) return true;
    if (trPhonesMatch(order.customerPhone, auth.phone)) return true;
    // Telefon AI siparişleri: customer_0… / phone_… / ham numara
    if (cid == 'phone_$authTen' ||
        cid == 'customer_$authTen' ||
        cid == 'customer_0$authTen') {
      return true;
    }
  }

  final email = auth.email?.trim().toLowerCase();
  if (email != null && email.isNotEmpty) {
    if (order.customerId == 'customer_$email') return true;
  }

  return false;
}
