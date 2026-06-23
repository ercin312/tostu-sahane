import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../shared/domain/entities/order.dart';
/// Telefon/e-posta format farklarından kaynaklanan customerId uyumsuzluklarını tolere eder.
bool orderBelongsToCustomer(Order order, AuthState auth) {
  if (order.customerId == auth.user.id) return true;

  final phoneDigits = auth.phone.replaceAll(RegExp(r'\D'), '');
  if (phoneDigits.isNotEmpty) {
    if (order.customerId == 'customer_$phoneDigits') return true;
    if (order.customerId.endsWith(phoneDigits)) return true;
  }

  final email = auth.email?.trim().toLowerCase();
  if (email != null && email.isNotEmpty) {
    if (order.customerId == 'customer_$email') return true;
  }

  return false;
}
