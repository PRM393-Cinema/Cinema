class RegisterRequest {
  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.password,
    this.phone,
  });

  final String fullName;
  final String email;
  final String password;
  final String? phone;

  Map<String, Object?> toJson() {
    final trimmedPhone = phone?.trim();

    return {
      'fullName': fullName,
      'email': email,
      'password': password,
      if (trimmedPhone != null && trimmedPhone.isNotEmpty)
        'phone': trimmedPhone,
    };
  }
}
