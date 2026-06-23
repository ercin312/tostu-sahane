class ProductReviewSubmissionException implements Exception {
  const ProductReviewSubmissionException(this.messageKey);

  final String messageKey;
}
