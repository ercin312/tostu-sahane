import '../../../../../shared/domain/entities/saved_card.dart';

class PaymentPageArgs {
  const PaymentPageArgs({
    required this.amount,
    this.savedCard,
  });

  final double amount;
  final SavedCard? savedCard;
}
