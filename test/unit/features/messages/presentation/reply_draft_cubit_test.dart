import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/presentation/bloc/reply_draft_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

Message _msg(String id) => Message(
  externalId: id,
  chatLid: 'c1',
  senderLid: 'alice',
  kind: MessageKind.dm,
  direction: MessageDirection.inbound,
  type: 'text',
  content: 'hola',
  mediaRef: null,
  mediaUrl: null,
  quotedId: null,
  timestampMs: 1700,
  status: null,
);

void main() {
  test('estado inicial es null (sin respuesta en curso)', () {
    final cubit = ReplyDraftCubit();
    addTearDown(cubit.close);
    expect(cubit.state, isNull);
  });

  test('setReply fija el mensaje citado; clear lo limpia', () {
    final cubit = ReplyDraftCubit();
    addTearDown(cubit.close);
    cubit.setReply(_msg('m1'));
    expect(cubit.state?.externalId, 'm1');
    cubit.clear();
    expect(cubit.state, isNull);
  });
}
