import 'package:cinema_fe/core/utils/account_validators.dart';
import 'package:flutter_test/flutter_test.dart';

// The same cases as AuthService.Tests/Integration/AccountValidationTests.cs:
// the form refuses what the server would.
void main() {
  test(
    'Emails need a domain with a suffix and fit the 150-character column',
    () {
      for (final email in [
        'jane@example.com',
        'khach.a+ve@test.local',
        ' jane@example.com ',
        '${'a' * 139}@test.local',
      ]) {
        expect(validateEmail(email), isNull, reason: email);
      }
      expect(validateEmail(''), 'Email is required.');
      for (final email in ['a@', 'a b@test.local', 'abc@def', 'khach@test.l']) {
        expect(
          validateEmail(email),
          'Please enter a valid email address.',
          reason: email,
        );
      }
      expect(
        validateEmail('${'a' * 140}@test.local'),
        'Email must be at most 150 characters.',
      );
    },
  );

  test('New passwords take 6 to 72 characters, counting accents as bytes', () {
    expect(validateNewPassword('Secret123'), isNull);
    expect(validateNewPassword('x' * 72), isNull);
    expect(validateNewPassword(''), 'Password is required.');
    expect(
      validateNewPassword('12345'),
      'Password must be at least 6 characters.',
    );
    expect(
      validateNewPassword('x' * 73),
      'Password must be at most 72 characters.',
    );
    // 49 characters, 77 bytes.
    expect(validateNewPassword('mậtkhẩu' * 7), contains('accented letters'));
    // Signing in only needs the password the account already has.
    expect(validateSignInPassword('123'), isNull);
    expect(validateSignInPassword(''), 'Password is required.');
  });

  test('The password has to be typed the same twice', () {
    expect(validatePasswordConfirmation('Secret123', 'Secret123'), isNull);
    expect(
      validatePasswordConfirmation('', 'Secret123'),
      'Please enter the password again.',
    );
    expect(
      validatePasswordConfirmation('Secret12', 'Secret123'),
      'Passwords do not match.',
    );
  });

  test('Names are required and fit 150 characters', () {
    expect(validateFullName('Jane Customer'), isNull);
    expect(validateFullName('N' * 150), isNull);
    expect(validateFullName('   '), 'Full name is required.');
    expect(
      validateFullName('N' * 151),
      'Full name must be at most 150 characters.',
    );
  });

  test('Phone numbers are optional, with 8 to 15 digits', () {
    for (final phone in [
      '',
      '0901234567',
      '0901 234 567',
      '+84 (90) 123-4567',
    ]) {
      expect(validatePhone(phone), isNull, reason: phone);
    }
    for (final phone in [
      '+++',
      '1234567',
      'abc12345678',
      '0901 234 567 890 1234',
      '09-01(23)+4567',
    ]) {
      expect(
        validatePhone(phone),
        'Phone number must have 8 to 15 digits.',
        reason: phone,
      );
    }
  });
}
