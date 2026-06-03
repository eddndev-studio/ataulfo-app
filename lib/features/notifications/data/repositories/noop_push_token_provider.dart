import '../../domain/repositories/push_token_provider.dart';

class NoopPushTokenProvider implements PushTokenProvider {
  const NoopPushTokenProvider();

  @override
  Future<String?> currentToken() async => null;

  @override
  Stream<String> get tokenRefreshes => const Stream<String>.empty();
}
