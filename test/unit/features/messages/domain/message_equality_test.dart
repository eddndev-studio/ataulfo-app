import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:flutter_test/flutter_test.dart';

Message _m({int? editedAtMs, int? revokedAtMs}) => Message(
  externalId: 'e1',
  chatLid: 'lid-1',
  senderLid: 'lid-1',
  kind: MessageKind.dm,
  direction: MessageDirection.outbound,
  type: 'text',
  content: 'hola',
  mediaRef: null,
  quotedId: null,
  timestampMs: 1700,
  status: MessageStatus.sent,
  editedAtMs: editedAtMs,
  revokedAtMs: revokedAtMs,
);

void main() {
  // La igualdad DEBE observar los marcadores de corrección: sin esto, un
  // catch-up que revoca un mensaje produce un estado "igual" y el bloc
  // suprime el repintado — la revocación jamás se pinta en un hilo abierto.
  test('== y hashCode observan editedAtMs/revokedAtMs', () {
    expect(_m(), _m());
    expect(_m(), isNot(_m(revokedAtMs: 9)));
    expect(_m(), isNot(_m(editedAtMs: 9)));
    expect(_m().hashCode, isNot(_m(revokedAtMs: 9).hashCode));
  });

  test('withStatus conserva los marcadores', () {
    final w = _m(editedAtMs: 5, revokedAtMs: 7).withStatus(MessageStatus.read);
    expect(w.editedAtMs, 5);
    expect(w.revokedAtMs, 7);
  });
}
