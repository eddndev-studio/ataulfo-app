import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/entities/thread_live_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveStatus', () {
    test('igualdad por valor (externalId + status)', () {
      const a = LiveStatus(externalId: 'o1', status: MessageStatus.read);
      const b = LiveStatus(externalId: 'o1', status: MessageStatus.read);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('difiere por externalId o por status', () {
      const base = LiveStatus(externalId: 'o1', status: MessageStatus.read);
      expect(
        base == const LiveStatus(externalId: 'o2', status: MessageStatus.read),
        isFalse,
      );
      expect(
        base ==
            const LiveStatus(externalId: 'o1', status: MessageStatus.delivered),
        isFalse,
      );
    });

    test('no es igual a otros ThreadLiveEvent', () {
      const status = LiveStatus(externalId: 'o1', status: MessageStatus.read);
      expect(status == const LiveReconnected(), isFalse);
    });
  });
}
