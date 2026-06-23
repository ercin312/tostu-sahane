import 'package:flutter_test/flutter_test.dart';
import 'package:tostu_sahane/core/reviews/product_review_rules.dart';
import 'package:tostu_sahane/features/auth/presentation/providers/auth_provider.dart';
import 'package:tostu_sahane/shared/domain/entities/order.dart';
import 'package:tostu_sahane/shared/domain/entities/product_review.dart';
import 'package:tostu_sahane/shared/domain/entities/user.dart';

AuthState _customerAuth() => AuthState(
      user: const User(
        id: 'customer_5551234567',
        name: 'Müşteri',
        role: UserRole.customer,
      ),
      phone: '5551234567',
    );

Order _deliveredOrder({
  required String id,
  required String productId,
  required DateTime deliveredAt,
}) {
  return Order(
    id: id,
    orderNumber: 1001,
    customerId: 'customer_5551234567',
    customerName: 'Test',
    branchId: 'branch_1',
    items: [
      CartItem(
        id: 'i1',
        productId: productId,
        productNameKey: 'product_kasarli_tost_name',
        unitPrice: 80,
        quantity: 1,
      ),
    ],
    totalAmount: 80,
    status: OrderStatus.delivered,
    createdAt: deliveredAt.subtract(const Duration(hours: 1)),
    address: 'Adres',
    paymentMethod: PaymentMethod.cashOnDelivery,
    statusTimestamps: {
      OrderStatus.received: deliveredAt.subtract(const Duration(hours: 1)),
      OrderStatus.delivered: deliveredAt,
    },
  );
}

void main() {
  group('ProductReviewRules', () {
    test('guest cannot review', () {
      final result = ProductReviewRules.evaluate(
        auth: null,
        productId: 'p1',
        customerOrders: const [],
        customerReviews: const [],
      );
      expect(result.canSubmit, isFalse);
      expect(result.reason, ProductReviewBlockReason.guest);
    });

    test('customer can review within 2 days of delivery', () {
      final deliveredAt = DateTime.now().subtract(const Duration(hours: 6));
      final result = ProductReviewRules.evaluate(
        auth: _customerAuth(),
        productId: 'p1',
        customerOrders: [
          _deliveredOrder(
            id: 'order_1',
            productId: 'p1',
            deliveredAt: deliveredAt,
          ),
        ],
        customerReviews: const [],
      );
      expect(result.canSubmit, isTrue);
      expect(result.orderId, 'order_1');
    });

    test('review window closes after 2 days', () {
      final deliveredAt = DateTime.now().subtract(const Duration(days: 3));
      final result = ProductReviewRules.evaluate(
        auth: _customerAuth(),
        productId: 'p1',
        customerOrders: [
          _deliveredOrder(
            id: 'order_1',
            productId: 'p1',
            deliveredAt: deliveredAt,
          ),
        ],
        customerReviews: const [],
      );
      expect(result.canSubmit, isFalse);
      expect(result.reason, ProductReviewBlockReason.windowExpired);
    });

    test('blocks duplicate review for same order and product', () {
      final deliveredAt = DateTime.now().subtract(const Duration(hours: 2));
      final result = ProductReviewRules.evaluate(
        auth: _customerAuth(),
        productId: 'p1',
        customerOrders: [
          _deliveredOrder(
            id: 'order_1',
            productId: 'p1',
            deliveredAt: deliveredAt,
          ),
        ],
        customerReviews: [
          ProductReview(
            id: 'r1',
            productId: 'p1',
            orderId: 'order_1',
            customerId: 'customer_5551234567',
            customerName: 'Müşteri',
            rating: 5,
            comment: 'Harika',
            createdAt: DateTime.now(),
            isApproved: true,
          ),
        ],
      );
      expect(result.canSubmit, isFalse);
      expect(result.reason, ProductReviewBlockReason.alreadyReviewed);
    });

    test('blocks when pending review exists', () {
      final deliveredAt = DateTime.now().subtract(const Duration(hours: 2));
      final result = ProductReviewRules.evaluate(
        auth: _customerAuth(),
        productId: 'p1',
        customerOrders: [
          _deliveredOrder(
            id: 'order_1',
            productId: 'p1',
            deliveredAt: deliveredAt,
          ),
        ],
        customerReviews: [
          ProductReview(
            id: 'r1',
            productId: 'p1',
            orderId: 'order_1',
            customerId: 'customer_5551234567',
            customerName: 'Müşteri',
            rating: 4,
            comment: 'Bekliyor',
            createdAt: DateTime.now(),
          ),
        ],
      );
      expect(result.canSubmit, isFalse);
      expect(result.reason, ProductReviewBlockReason.pendingApproval);
    });
  });
}
