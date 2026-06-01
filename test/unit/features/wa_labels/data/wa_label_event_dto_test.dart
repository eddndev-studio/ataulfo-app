import 'package:ataulfo/features/wa_labels/data/dto/wa_label_event_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WaLabelEventResp.fromJson', () {
    test('EDITED: catálogo con name + color', () {
      final r = WaLabelEventResp.fromJson(<String, dynamic>{
        'botId': 'bot-1',
        'kind': 'EDITED',
        'waLabelId': '1000',
        'name': 'VIP',
        'color': 3,
        'labeled': false,
        'at': '2026-05-31T12:00:00Z',
      });
      expect(r.kind, 'EDITED');
      expect(r.waLabelId, '1000');
      expect(r.name, 'VIP');
      expect(r.color, 3);
      expect(r.chatLid, isNull);
      expect(r.messageId, isNull);
    });

    test('REMOVED: tombstone, name omitido → null', () {
      final r = WaLabelEventResp.fromJson(<String, dynamic>{
        'botId': 'bot-1',
        'kind': 'REMOVED',
        'waLabelId': '1000',
        'color': 7,
        'labeled': false,
        'at': '2026-05-31T12:00:00Z',
      });
      expect(r.kind, 'REMOVED');
      expect(r.name, isNull);
      expect(r.color, 7);
    });

    test('CHAT: chatLid + labeled, color presente (0 válido)', () {
      final r = WaLabelEventResp.fromJson(<String, dynamic>{
        'botId': 'bot-1',
        'kind': 'CHAT',
        'waLabelId': '1000',
        'color': 0,
        'chatLid': 'c1',
        'labeled': true,
        'at': '2026-05-31T12:00:00Z',
      });
      expect(r.kind, 'CHAT');
      expect(r.chatLid, 'c1');
      expect(r.color, 0);
      expect(r.labeled, isTrue);
      expect(r.messageId, isNull);
    });

    test('MESSAGE: chatLid + messageId + labeled', () {
      final r = WaLabelEventResp.fromJson(<String, dynamic>{
        'botId': 'bot-1',
        'kind': 'MESSAGE',
        'waLabelId': '1000',
        'color': 3,
        'chatLid': 'c1',
        'messageId': 'wamid.1',
        'labeled': false,
        'at': '2026-05-31T12:00:00Z',
      });
      expect(r.kind, 'MESSAGE');
      expect(r.messageId, 'wamid.1');
      expect(r.labeled, isFalse);
    });

    test('campo requerido ausente (waLabelId) → FormatException', () {
      expect(
        () => WaLabelEventResp.fromJson(<String, dynamic>{
          'botId': 'bot-1',
          'kind': 'EDITED',
          'color': 3,
          'labeled': false,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('color ausente → FormatException (siempre presente en el contrato)', () {
      expect(
        () => WaLabelEventResp.fromJson(<String, dynamic>{
          'botId': 'bot-1',
          'kind': 'EDITED',
          'waLabelId': '1000',
          'labeled': false,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
