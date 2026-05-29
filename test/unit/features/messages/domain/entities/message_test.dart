import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessageKind.fromWire', () {
    test('DM/GROUP → enum', () {
      expect(MessageKind.fromWire('DM'), MessageKind.dm);
      expect(MessageKind.fromWire('GROUP'), MessageKind.group);
    });

    test(
      'valor desconocido → ArgumentError (fail-loud, kind siempre viene)',
      () {
        expect(() => MessageKind.fromWire('CHANNEL'), throwsArgumentError);
      },
    );
  });

  group('MessageDirection.fromWire', () {
    test('INBOUND/OUTBOUND → enum', () {
      expect(MessageDirection.fromWire('INBOUND'), MessageDirection.inbound);
      expect(MessageDirection.fromWire('OUTBOUND'), MessageDirection.outbound);
    });

    test('valor desconocido → ArgumentError (fail-loud)', () {
      expect(() => MessageDirection.fromWire('SIDEWAYS'), throwsArgumentError);
    });
  });

  group('MessageStatus.fromWire', () {
    test('SENT/DELIVERED/READ/FAILED → enum', () {
      expect(MessageStatus.fromWire('SENT'), MessageStatus.sent);
      expect(MessageStatus.fromWire('DELIVERED'), MessageStatus.delivered);
      expect(MessageStatus.fromWire('READ'), MessageStatus.read);
      expect(MessageStatus.fromWire('FAILED'), MessageStatus.failed);
    });

    // status es omitempty + sólo OUTBOUND: ausente/vacío NO es drift, es
    // "sin estado de entrega" (los INBOUND no llevan máquina de estados).
    test('null o vacío → null (NO lanza)', () {
      expect(MessageStatus.fromWire(null), isNull);
      expect(MessageStatus.fromWire(''), isNull);
    });

    test('valor desconocido NO vacío → ArgumentError (fail-loud)', () {
      expect(() => MessageStatus.fromWire('PENDING'), throwsArgumentError);
    });
  });

  group('Message igualdad por valor', () {
    Message base() => const Message(
      externalId: 'e1',
      chatLid: 'lid-1',
      senderLid: 'alice',
      kind: MessageKind.group,
      direction: MessageDirection.inbound,
      type: 'text',
      content: 'hola',
      mediaRef: null,
      quotedId: null,
      timestampMs: 1700,
      status: null,
    );

    test('dos mensajes con los mismos campos son iguales', () {
      expect(base(), base());
      expect(base().hashCode, base().hashCode);
    });

    test('difiere si cambia un campo', () {
      const other = Message(
        externalId: 'e2', // distinto
        chatLid: 'lid-1',
        senderLid: 'alice',
        kind: MessageKind.group,
        direction: MessageDirection.inbound,
        type: 'text',
        content: 'hola',
        mediaRef: null,
        quotedId: null,
        timestampMs: 1700,
        status: null,
      );
      expect(base() == other, isFalse);
    });
  });
}
