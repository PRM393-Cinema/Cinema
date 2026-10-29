abstract interface class AccessTokenProvider {
  Future<String?> accessToken();

  // Called after the backend rejects [failedToken] with 401. Returns a fresh
  // access token, or null when the session cannot be renewed.
  Future<String?> refreshAccessToken({required String failedToken});

  Future<void> expireSession({required String message});
}
