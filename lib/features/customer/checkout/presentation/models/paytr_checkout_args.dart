import '../../../../../shared/domain/entities/order.dart';

class PaytrCheckoutArgs {
  const PaytrCheckoutArgs({
    required this.amount,
    required this.email,
    required this.customerName,
    required this.phone,
    required this.address,
    required this.basketSummary,
    required this.items,
  });

  final double amount;
  final String email;
  final String customerName;
  final String phone;
  final String address;
  final String basketSummary;
  final List<CartItem> items;
}
