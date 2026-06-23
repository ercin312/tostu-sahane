class OperationalPurgeResult {
  const OperationalPurgeResult({
    required this.ordersDeleted,
    required this.reviewsDeleted,
    required this.remittancesDeleted,
  });

  final int ordersDeleted;
  final int reviewsDeleted;
  final int remittancesDeleted;

  int get total => ordersDeleted + reviewsDeleted + remittancesDeleted;
}
