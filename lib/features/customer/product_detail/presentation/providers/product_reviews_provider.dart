import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/reviews/product_review_exceptions.dart';
import '../../../../../core/reviews/product_review_rules.dart';
import '../../../../../shared/domain/entities/product_review.dart';
import '../../../../../shared/domain/entities/user.dart';
import '../../../../../shared/presentation/providers/orders_provider.dart';
import '../../../../../shared/presentation/providers/repository_providers.dart';

final productReviewsProvider =
    FutureProvider.family<List<ProductReview>, String>((ref, productId) async {
  return ref
      .read(productReviewRepositoryProvider)
      .getApprovedReviews(productId);
});

final productReviewStatsProvider =
    Provider.family<({double average, int count}), String>((ref, productId) {
  final reviews = ref.watch(productReviewsProvider(productId)).value ?? [];
  if (reviews.isEmpty) return (average: 0.0, count: 0);
  final sum = reviews.fold<int>(0, (s, r) => s + r.rating);
  return (average: sum / reviews.length, count: reviews.length);
});

final customerProductReviewsProvider =
    FutureProvider<List<ProductReview>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth == null || auth.user.role != UserRole.customer) return [];
  return ref
      .read(productReviewRepositoryProvider)
      .getCustomerReviews(auth.user.id);
});

final productReviewEligibilityProvider =
    Provider.family<ProductReviewEligibility, String>((ref, productId) {
  final auth = ref.watch(authProvider);
  final orders = ref.watch(customerOrdersProvider);
  final reviews = ref.watch(customerProductReviewsProvider).value ?? [];
  return ProductReviewRules.evaluate(
    auth: auth,
    productId: productId,
    customerOrders: orders,
    customerReviews: reviews,
  );
});

final pendingProductReviewsProvider =
    StreamProvider<List<ProductReview>>((ref) {
  return ref.read(productReviewRepositoryProvider).watchPendingReviews();
});

final adminPendingReviewCountProvider = Provider<int>((ref) {
  final pending = ref.watch(pendingProductReviewsProvider).value ?? [];
  return pending.length;
});

final orderIdsWithPendingReviewProvider = Provider<Set<String>>((ref) {
  final pending = ref.watch(pendingProductReviewsProvider).value ?? [];
  return pending.map((r) => r.orderId).whereType<String>().toSet();
});

class ProductReviewsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> submit({
    required String productId,
    required int rating,
    required String comment,
  }) async {
    final auth = ref.read(authProvider);
    if (auth == null || auth.user.role != UserRole.customer || rating < 1) {
      throw const ProductReviewSubmissionException(
        LocaleKeys.productReviewLoginRequired,
      );
    }

    final eligibility = ProductReviewRules.evaluate(
      auth: auth,
      productId: productId,
      customerOrders: ref.read(customerOrdersProvider),
      customerReviews: await ref.read(customerProductReviewsProvider.future),
    );

    if (!eligibility.canSubmit || eligibility.orderId == null) {
      throw ProductReviewSubmissionException(
        _messageKeyForReason(eligibility.reason),
      );
    }

    final review = ProductReview(
      id: 'review_${DateTime.now().millisecondsSinceEpoch}',
      productId: productId,
      orderId: eligibility.orderId,
      customerId: auth.user.id,
      customerName: auth.user.name,
      rating: rating,
      comment: comment.trim(),
      createdAt: DateTime.now(),
    );

    await ref.read(productReviewRepositoryProvider).submitReview(review);
    ref.invalidate(productReviewsProvider(productId));
    ref.invalidate(customerProductReviewsProvider);
    ref.invalidate(productReviewEligibilityProvider(productId));
  }

  String _messageKeyForReason(ProductReviewBlockReason? reason) {
    return switch (reason) {
      ProductReviewBlockReason.guest ||
      ProductReviewBlockReason.notCustomer =>
        LocaleKeys.productReviewLoginRequired,
      ProductReviewBlockReason.noPurchase =>
        LocaleKeys.productReviewPurchaseRequired,
      ProductReviewBlockReason.windowExpired =>
        LocaleKeys.productReviewWindowExpired,
      ProductReviewBlockReason.alreadyReviewed =>
        LocaleKeys.productReviewAlreadySubmitted,
      ProductReviewBlockReason.pendingApproval =>
        LocaleKeys.productReviewPendingApproval,
      null => LocaleKeys.productReviewPurchaseRequired,
    };
  }

  Future<void> approve(String reviewId, String productId) async {
    await ref.read(productReviewRepositoryProvider).approveReview(reviewId);
    ref.invalidate(productReviewsProvider(productId));
    ref.invalidate(customerProductReviewsProvider);
    ref.invalidate(productReviewEligibilityProvider(productId));
    await ref.read(ordersProvider.notifier).refresh();
  }

  Future<void> reject(String reviewId, String productId) async {
    await ref.read(productReviewRepositoryProvider).rejectReview(reviewId);
    ref.invalidate(productReviewsProvider(productId));
    ref.invalidate(customerProductReviewsProvider);
    ref.invalidate(productReviewEligibilityProvider(productId));
    await ref.read(ordersProvider.notifier).refresh();
  }
}

final productReviewsNotifierProvider =
    AsyncNotifierProvider<ProductReviewsNotifier, void>(
  ProductReviewsNotifier.new,
);

String productReviewBlockMessageKey(ProductReviewBlockReason reason) {
  return switch (reason) {
    ProductReviewBlockReason.guest ||
    ProductReviewBlockReason.notCustomer =>
      LocaleKeys.productReviewLoginRequired,
    ProductReviewBlockReason.noPurchase =>
      LocaleKeys.productReviewPurchaseRequired,
    ProductReviewBlockReason.windowExpired =>
      LocaleKeys.productReviewWindowExpired,
    ProductReviewBlockReason.alreadyReviewed =>
      LocaleKeys.productReviewAlreadySubmitted,
    ProductReviewBlockReason.pendingApproval =>
      LocaleKeys.productReviewPendingApproval,
  };
}
