abstract interface class PushTokenProvider {
  Future<String?> currentToken();

  Stream<String> get tokenRefreshes;
}
