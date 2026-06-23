import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../shared/domain/entities/order.dart';
import '../../shared/domain/entities/product_review.dart';
import '../../shared/domain/entities/user.dart';
import '../utils/customer_order_matching.dart';

enum ProductReviewBlockReason {
  guest,
  notCustomer,
  noPurchase,
  windowExpired,
  alreadyReviewed,
  pendingApproval,
}

class ProductReviewEligibility {
  const ProductReviewEligibility._({
    required this.canSubmit,
    this.orderId,
    this.reason,
    this.hoursRemaining,
  });

  const ProductReviewEligibility.canSubmit({
    required String orderId,
    required int hoursRemaining,
  }) : this._(
          canSubmit: true,
          orderId: orderId,
          hoursRemaining: hoursRemaining,
        );

  const ProductReviewEligibility.blocked(ProductReviewBlockReason reason)
      : this._(canSubmit: false, reason: reason);

  final bool canSubmit;
  final String? orderId;
  final ProductReviewBlockReason? reason;
  final int? hoursRemaining;
}

abstract final class ProductReviewRules {
  static const reviewWindowDays = 2;

  static ProductReviewEligibility evaluate({
    required AuthState? auth,
    required String productId,
    required List<Order> customerOrders,
    required List<ProductReview> customerReviews,
  }) {
    if (auth == null) {
      return const ProductReviewEligibility.blocked(
        ProductReviewBlockReason.guest,
      );
    }
    if (auth.user.role != UserRole.customer) {
      return const ProductReviewEligibility.blocked(
        ProductReviewBlockReason.notCustomer,
      );
    }

    final now = DateTime.now();
    final reviewsForProduct = customerReviews.where(
      (review) =>
          review.productId == productId &&
          review.customerId == auth.user.id,
    );

    if (reviewsForProduct.any((r) => !r.isApproved)) {
      return const ProductReviewEligibility.blocked(
        ProductReviewBlockReason.pendingApproval,
      );
    }

    Order? bestOrder;
    var bestHoursRemaining = -1;

    for (final order in customerOrders) {
      if (order.status != OrderStatus.delivered) continue;
      if (!orderBelongsToCustomer(order, auth)) continue;
      if (!_orderContainsProduct(order, productId)) continue;

      final deliveredAt =
          order.atStatus(OrderStatus.delivered) ?? order.createdAt;
      final deadline =
          deliveredAt.add(const Duration(days: reviewWindowDays));
      if (now.isAfter(deadline)) continue;

      final alreadyReviewed = reviewsForProduct.any(
        (review) => review.orderId == order.id && review.isApproved,
      );
      if (alreadyReviewed) continue;

      final hoursRemaining = deadline.difference(now).inHours;
      if (hoursRemaining > bestHoursRemaining) {
        bestHoursRemaining = hoursRemaining;
        bestOrder = order;
      }
    }

    if (bestOrder != null) {
      return ProductReviewEligibility.canSubmit(
        orderId: bestOrder.id,
        hoursRemaining: bestHoursRemaining,
      );
    }

    if (reviewsForProduct.any((r) => r.isApproved)) {
      return const ProductReviewEligibility.blocked(
        ProductReviewBlockReason.alreadyReviewed,
      );
    }

    final hadDeliveredProduct = customerOrders.any(
      (order) =>
          order.status == OrderStatus.delivered &&
          orderBelongsToCustomer(order, auth) &&
          _orderContainsProduct(order, productId),
    );
    if (hadDeliveredProduct) {
      return const ProductReviewEligibility.blocked(
        ProductReviewBlockReason.windowExpired,
      );
    }

    return const ProductReviewEligibility.blocked(
      ProductReviewBlockReason.noPurchase,
    );
  }

  static bool _orderContainsProduct(Order order, String productId) {
    return order.items.any((item) => item.productId == productId);
  }
}
