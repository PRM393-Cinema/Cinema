class OtpSentResponse {
  const OtpSentResponse({
    required this.email,
    required this.message,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
  });

  factory OtpSentResponse.fromJson(Map<String, Object?> json) {
    return OtpSentResponse(
      email: json['email'] as String,
      message: json['message'] as String? ?? '',
      expiresInSeconds: json['expiresInSeconds'] as int? ?? 0,
      resendAfterSeconds: json['resendAfterSeconds'] as int? ?? 0,
    );
  }

  final String email;
  final String message;
  final int expiresInSeconds;
  final int resendAfterSeconds;
}
