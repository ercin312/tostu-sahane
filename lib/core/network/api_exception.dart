class ApiException implements Exception {
  const ApiException({
    required this.messageKey,
    this.statusCode,
    this.detail,
  });

  final String messageKey;
  final int? statusCode;
  final String? detail;

  @override
  String toString() => detail ?? messageKey;
}
