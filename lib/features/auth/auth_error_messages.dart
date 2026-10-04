import '../../core/network/api_exception.dart';

String authErrorMessage(ApiException error) {
  final rawMessage = error.message.trim();
  final normalized = _normalize(rawMessage);

  if (_isTimeout(normalized)) {
    return 'The request timed out. Please try again.';
  }

  if (_isNetworkError(normalized)) {
    return 'Unable to connect to the server. Please try again.';
  }

  if (_isEmailVerificationError(normalized)) {
    return 'Please verify your email before signing in.';
  }

  if (_isInvalidOtpError(normalized)) {
    return 'Invalid or expired verification code.';
  }

  if (error.statusCode == 401 || _isInvalidCredentialsError(normalized)) {
    return 'Invalid email or password.';
  }

  if (_isUnsafeToDisplay(rawMessage, normalized)) {
    return 'Something went wrong. Please try again.';
  }

  if (rawMessage.isNotEmpty && !_containsVietnamese(rawMessage)) {
    return rawMessage;
  }

  final statusCode = error.statusCode;
  if (statusCode == null) {
    return 'Something went wrong. Please try again.';
  }

  return switch (statusCode) {
    400 => 'Please check your information and try again.',
    403 => 'Please verify your email before signing in.',
    429 => 'Too many requests. Please wait and try again.',
    >= 500 => 'Something went wrong. Please try again.',
    _ => 'Something went wrong. Please try again.',
  };
}

String _normalize(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    buffer.write(_vietnameseMarks[rune] ?? String.fromCharCode(rune));
  }
  return buffer.toString();
}

const _vietnameseMarks = <int, String>{
  0x00e0: 'a',
  0x00e1: 'a',
  0x1ea1: 'a',
  0x1ea3: 'a',
  0x00e3: 'a',
  0x00e2: 'a',
  0x1ea7: 'a',
  0x1ea5: 'a',
  0x1ead: 'a',
  0x1ea9: 'a',
  0x1eab: 'a',
  0x0103: 'a',
  0x1eb1: 'a',
  0x1eaf: 'a',
  0x1eb7: 'a',
  0x1eb3: 'a',
  0x1eb5: 'a',
  0x00e8: 'e',
  0x00e9: 'e',
  0x1eb9: 'e',
  0x1ebb: 'e',
  0x1ebd: 'e',
  0x00ea: 'e',
  0x1ec1: 'e',
  0x1ebf: 'e',
  0x1ec7: 'e',
  0x1ec3: 'e',
  0x1ec5: 'e',
  0x00ec: 'i',
  0x00ed: 'i',
  0x1ecb: 'i',
  0x1ec9: 'i',
  0x0129: 'i',
  0x00f2: 'o',
  0x00f3: 'o',
  0x1ecd: 'o',
  0x1ecf: 'o',
  0x00f5: 'o',
  0x00f4: 'o',
  0x1ed3: 'o',
  0x1ed1: 'o',
  0x1ed9: 'o',
  0x1ed5: 'o',
  0x1ed7: 'o',
  0x01a1: 'o',
  0x1edd: 'o',
  0x1edb: 'o',
  0x1ee3: 'o',
  0x1edf: 'o',
  0x1ee1: 'o',
  0x00f9: 'u',
  0x00fa: 'u',
  0x1ee5: 'u',
  0x1ee7: 'u',
  0x0169: 'u',
  0x01b0: 'u',
  0x1eeb: 'u',
  0x1ee9: 'u',
  0x1ef1: 'u',
  0x1eed: 'u',
  0x1eef: 'u',
  0x1ef3: 'y',
  0x00fd: 'y',
  0x1ef5: 'y',
  0x1ef7: 'y',
  0x1ef9: 'y',
  0x0111: 'd',
};

bool _isTimeout(String normalized) {
  return normalized.contains('timeout') ||
      normalized.contains('timed out') ||
      normalized.contains('qua thoi gian');
}

bool _isNetworkError(String normalized) {
  return normalized.contains('cannot reach') ||
      normalized.contains('connect') ||
      normalized.contains('connection') ||
      normalized.contains('network') ||
      normalized.contains('server unreachable') ||
      normalized.contains('khong the ket noi') ||
      normalized.contains('mat ket noi');
}

bool _isEmailVerificationError(String normalized) {
  return normalized.contains('email not verified') ||
      normalized.contains('verify your email') ||
      normalized.contains('email is not verified') ||
      normalized.contains('not activated') ||
      normalized.contains('inactive account') ||
      normalized.contains('chua xac thuc') ||
      normalized.contains('chua kich hoat');
}

bool _isInvalidOtpError(String normalized) {
  final mentionsCode =
      normalized.contains('otp') ||
      normalized.contains('code') ||
      normalized.contains('verification') ||
      normalized.contains('ma xac thuc');
  final invalidOrExpired =
      normalized.contains('invalid') ||
      normalized.contains('expired') ||
      normalized.contains('incorrect') ||
      normalized.contains('sai') ||
      normalized.contains('het han');

  return mentionsCode && invalidOrExpired;
}

bool _isInvalidCredentialsError(String normalized) {
  return normalized.contains('bad credentials') ||
      normalized.contains('invalid credentials') ||
      normalized.contains('invalid email or password') ||
      normalized.contains('email or password is incorrect') ||
      normalized.contains('incorrect email or password') ||
      normalized.contains('wrong password') ||
      normalized.contains('sai email') ||
      normalized.contains('sai mat khau') ||
      normalized.contains('khong dung') ||
      normalized.contains('dang nhap khong thanh cong');
}

bool _isUnsafeToDisplay(String rawMessage, String normalized) {
  final trimmed = rawMessage.trimLeft();
  return trimmed.startsWith('{') ||
      trimmed.startsWith('[') ||
      normalized.contains('<html') ||
      normalized.contains('<!doctype') ||
      normalized.contains('stack trace') ||
      normalized.contains('exception:') ||
      normalized.contains('null pointer') ||
      normalized.contains('sql') ||
      normalized.contains('internal server error');
}

bool _containsVietnamese(String value) {
  return RegExp('[\\u00c0-\\u1ef9]').hasMatch(value);
}
