class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.details});

  final int? statusCode;
  final String message;
  final Object? details;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' [$statusCode]';
    return 'ApiException$code: $message';
  }
}
