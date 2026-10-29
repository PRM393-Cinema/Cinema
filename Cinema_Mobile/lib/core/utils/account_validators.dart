import 'dart:convert';

// Rules for account fields (sign in, sign up, password reset, accounts made
// by Admin), the same ones AuthService checks (Helpers/AccountValidation.cs),
// so a mistake shows on the form before anything is sent.
abstract final class AccountRules {
  // The users.email column.
  static const emailMaxLength = 150;
  static const passwordMinLength = 6;

  // BCrypt only hashes the first 72 bytes and silently drops the rest.
  static const passwordMaxBytes = 72;

  // The users.full_name column.
  static const fullNameMaxLength = 150;
  static const phoneMinDigits = 8;
  static const phoneMaxDigits = 15;

  // The users.phone column, separators included.
  static const phoneMaxLength = 20;
}

// A domain with a suffix of at least two letters and no spaces, so
// "a b@c" and "abc@def" are refused.
final _emailPattern = RegExp(
  r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}$',
);

// Digits, maybe a leading +, separated by spaces, dots, dashes or brackets.
final _phonePattern = RegExp(r'^\+?[0-9 .()-]+$');

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Email is required.';
  }
  if (email.length > AccountRules.emailMaxLength) {
    return 'Email must be at most ${AccountRules.emailMaxLength} characters.';
  }
  if (!_emailPattern.hasMatch(email)) {
    return 'Please enter a valid email address.';
  }
  return null;
}

// The password of an existing account: whatever it was set to.
String? validateSignInPassword(String? value) =>
    (value ?? '').isEmpty ? 'Password is required.' : null;

// A new password: 6 to 72 characters. Accented letters take 2 or 3 bytes, so
// a long Vietnamese password can pass 72 characters' worth of bytes.
String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) {
    return 'Password is required.';
  }
  if (password.length < AccountRules.passwordMinLength) {
    return 'Password must be at least ${AccountRules.passwordMinLength} '
        'characters.';
  }
  if (password.length > AccountRules.passwordMaxBytes) {
    return 'Password must be at most ${AccountRules.passwordMaxBytes} '
        'characters.';
  }
  if (utf8.encode(password).length > AccountRules.passwordMaxBytes) {
    return 'Password is too long: accented letters count as 2 or 3 '
        'characters.';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  if ((value ?? '').isEmpty) {
    return 'Please enter the password again.';
  }
  return value == password ? null : 'Passwords do not match.';
}

String? validateFullName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) {
    return 'Full name is required.';
  }
  if (name.length > AccountRules.fullNameMaxLength) {
    return 'Full name must be at most ${AccountRules.fullNameMaxLength} '
        'characters.';
  }
  return null;
}

// Optional: empty is fine.
String? validatePhone(String? value) {
  final phone = value?.trim() ?? '';
  if (phone.isEmpty) {
    return null;
  }
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '').length;
  if (phone.length > AccountRules.phoneMaxLength ||
      !_phonePattern.hasMatch(phone) ||
      digits < AccountRules.phoneMinDigits ||
      digits > AccountRules.phoneMaxDigits) {
    return 'Phone number must have ${AccountRules.phoneMinDigits} to '
        '${AccountRules.phoneMaxDigits} digits.';
  }
  return null;
}
