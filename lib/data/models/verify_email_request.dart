class VerifyEmailRequest {
  const VerifyEmailRequest({
    required this.email,
    required this.otp,
    required this.password,
  });

  final String email;
  final String otp;
  final String password;

  Map<String, Object?> toJson() {
    return {'email': email, 'otp': otp, 'password': password};
  }
}
