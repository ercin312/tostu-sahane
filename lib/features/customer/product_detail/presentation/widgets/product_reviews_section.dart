import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/locale_keys.dart';
import '../../../../../core/reviews/product_review_exceptions.dart';
import '../../../../../core/reviews/product_review_rules.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/localized_text.dart';
import '../../../../../shared/domain/entities/product.dart';
import '../../../../../shared/domain/entities/product_review.dart';
import '../providers/product_reviews_provider.dart';

class ProductReviewsSection extends ConsumerStatefulWidget {
  const ProductReviewsSection({super.key, required this.product});

  final Product product;

  @override
  ConsumerState<ProductReviewsSection> createState() =>
      _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends ConsumerState<ProductReviewsSection> {
  var _rating = 0;
  final _commentController = TextEditingController();
  var _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0 || _commentController.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      await ref.read(productReviewsNotifierProvider.notifier).submit(
            productId: widget.product.id,
            rating: _rating,
            comment: _commentController.text,
          );
      if (mounted) {
        setState(() {
          _submitting = false;
          _rating = 0;
          _commentController.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.productReviewSubmitted.tr())),
        );
      }
    } on ProductReviewSubmissionException catch (error) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.messageKey.tr())),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.commonError.tr())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewsAsync = ref.watch(productReviewsProvider(widget.product.id));
    final stats = ref.watch(productReviewStatsProvider(widget.product.id));
    final eligibility =
        ref.watch(productReviewEligibilityProvider(widget.product.id));

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  LocaleKeys.productReviewsTitle.tr(),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (stats.count > 0)
                _RatingBadge(average: stats.average, count: stats.count),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          reviewsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Text(LocaleKeys.commonError.tr()),
            data: (reviews) {
              if (reviews.isEmpty) {
                return Text(
                  LocaleKeys.productReviewsEmpty.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                );
              }
              return Column(
                children: reviews
                    .take(6)
                    .map((r) => _ReviewCard(review: r))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          if (eligibility.canSubmit)
            _ReviewForm(
              rating: _rating,
              submitting: _submitting,
              commentController: _commentController,
              hoursRemaining: eligibility.hoursRemaining,
              onRatingChanged: (value) => setState(() => _rating = value),
              onSubmit: _submit,
            )
          else
            _ReviewBlockedNotice(reason: eligibility.reason),
        ],
      ),
    );
  }
}

class _ReviewForm extends StatelessWidget {
  const _ReviewForm({
    required this.rating,
    required this.submitting,
    required this.commentController,
    required this.hoursRemaining,
    required this.onRatingChanged,
    required this.onSubmit,
  });

  final int rating;
  final bool submitting;
  final TextEditingController commentController;
  final int? hoursRemaining;
  final ValueChanged<int> onRatingChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.productReviewWrite.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (hoursRemaining != null) ...[
          const SizedBox(height: 4),
          Text(
            LocaleKeys.productReviewTimeLeft.tr(
              namedArgs: {'hours': '$hoursRemaining'},
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final star = index + 1;
            return IconButton(
              onPressed: submitting ? null : () => onRatingChanged(star),
              icon: Icon(
                star <= rating
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                color: Colors.amber,
                size: 32,
              ),
            );
          }),
        ),
        TextField(
          controller: commentController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: LocaleKeys.productReviewCommentHint.tr(),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            filled: true,
            fillColor: AppColors.background,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          LocaleKeys.productReviewPendingNote.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: submitting || rating == 0 ? null : onSubmit,
            child: submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(LocaleKeys.productReviewSubmit.tr()),
          ),
        ),
      ],
    );
  }
}

class _ReviewBlockedNotice extends StatelessWidget {
  const _ReviewBlockedNotice({required this.reason});

  final ProductReviewBlockReason? reason;

  @override
  Widget build(BuildContext context) {
    if (reason == null) return const SizedBox.shrink();

    final icon = switch (reason!) {
      ProductReviewBlockReason.guest ||
      ProductReviewBlockReason.notCustomer =>
        Icons.login_rounded,
      ProductReviewBlockReason.noPurchase => Icons.shopping_bag_outlined,
      ProductReviewBlockReason.windowExpired => Icons.timer_off_outlined,
      ProductReviewBlockReason.alreadyReviewed => Icons.check_circle_outline,
      ProductReviewBlockReason.pendingApproval => Icons.hourglass_top_rounded,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              productReviewBlockMessageKey(reason!).tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.average, required this.count});

  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade100,
            Colors.amber.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
          const SizedBox(width: 4),
          Text(
            average.toStringAsFixed(1),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          Text(
            ' ($count)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final ProductReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  localizedOrRaw(review.customerName)
                      .characters
                      .first
                      .toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizedOrRaw(review.customerName),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      DateFormat('dd.MM.yyyy').format(review.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(
                  review.rating,
                  (_) =>
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(review.comment),
          ],
        ],
      ),
    );
  }
}
