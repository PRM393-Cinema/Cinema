class VerifyEmailArguments {
  const VerifyEmailArguments({
    required this.email,
    required this.password,
    this.expiresInSeconds = 0,
    this.resendAfterSeconds = 0,
  });

  final String email;
  final String password;
  final int expiresInSeconds;
  final int resendAfterSeconds;
}
