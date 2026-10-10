class ApiException implements Exception {
  const ApiException({required this.message, this.statusCode, this.details});

  final int? statusCode;
  final String message;
  final Object? details;

  bool get isAccountLocked =>
      (statusCode == 401 || statusCode == 403) &&
      ((details is Map && (details as Map)['errorCode'] == 'ACCOUNT_LOCKED') ||
          message == 'Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.' ||
          message == 'Tài khoản đã bị vô hiệu hóa.');

  bool get requiresSignInAgain =>
      isAccountLocked ||
      (statusCode == 403 &&
          details is Map &&
          (details as Map)['errorCode'] == 'ROLE_CHANGED');

  @override
  String toString() {
    final code = statusCode == null ? '' : ' [$statusCode]';
    return 'ApiException$code: $message';
  }
}
