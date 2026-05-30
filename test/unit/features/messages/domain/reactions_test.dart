import 'package:ataulfo/features/messages/domain/entities/message.dart';
import 'package:ataulfo/features/messages/domain/reactions.dart';
import 'package:flutter_test/flutter_test.dart';

Message msg({
  required String externalId,
  String senderLid = 'alice',
  String type = 'text',
  String content = 'hola',
  String? quotedId,
  int ts = 1700,
}) => Message(
  externalId: externalId,
  chatLid: 'lid-1',
  senderLid: senderLid,
  kind: MessageKind.dm,
  direction: MessageDirection.inbound,
  type: type,
  content: content,
  mediaRef: null,
  quotedId: quotedId,
  timestampMs: ts,
  status: null,
);

Message reaction({
  required String externalId,
  required String target,
  required String emoji,
  String senderLid = 'alice',
  int ts = 1800,
}) => msg(
  externalId: externalId,
  senderLid: senderLid,
  type: 'reaction',
  content: emoji,
  quotedId: target,
  ts: ts,
);

void main() {
  group('foldReactions', () {
    test('una reacción se dobla sobre su target y NO queda como mensaje', () {
      final all = <Message>[
        msg(externalId: 'm1', content: 'hola'),
        reaction(externalId: 'r1', target: 'm1', emoji: '👍'),
      ];
      final folded = foldReactions(all);

      expect(folded.renderable.map((m) => m.externalId), <String>['m1']);
      expect(folded.byTarget['m1'], <ReactionTally>[
        const ReactionTally('👍', 1),
      ]);
    });

    test('mismo emoji de dos remitentes cuenta 2', () {
      final all = <Message>[
        msg(externalId: 'm1'),
        reaction(externalId: 'r1', target: 'm1', emoji: '❤️', senderLid: 'a'),
        reaction(externalId: 'r2', target: 'm1', emoji: '❤️', senderLid: 'b'),
      ];
      final folded = foldReactions(all);
      expect(folded.byTarget['m1'], <ReactionTally>[
        const ReactionTally('❤️', 2),
      ]);
    });

    test('un remitente sólo tiene una reacción: la última gana', () {
      final all = <Message>[
        msg(externalId: 'm1'),
        reaction(externalId: 'r1', target: 'm1', emoji: '👍', ts: 1800),
        reaction(externalId: 'r2', target: 'm1', emoji: '😂', ts: 1900),
      ];
      final folded = foldReactions(all);
      expect(folded.byTarget['m1'], <ReactionTally>[
        const ReactionTally('😂', 1),
      ]);
    });

    test('emoji vacío quita la reacción del remitente', () {
      final all = <Message>[
        msg(externalId: 'm1'),
        reaction(externalId: 'r1', target: 'm1', emoji: '👍', ts: 1800),
        reaction(externalId: 'r2', target: 'm1', emoji: '', ts: 1900),
      ];
      final folded = foldReactions(all);
      // Sin reacciones vivas ⇒ el target no aparece en el mapa.
      expect(folded.byTarget.containsKey('m1'), isFalse);
    });

    test('reacción sin target (quotedId null) se ignora sin romper', () {
      final all = <Message>[
        msg(externalId: 'm1'),
        msg(externalId: 'r1', type: 'reaction', content: '👍', quotedId: null),
      ];
      final folded = foldReactions(all);
      // No es renderable (es reacción) y no cuenta para ningún target.
      expect(folded.renderable.map((m) => m.externalId), <String>['m1']);
      expect(folded.byTarget, isEmpty);
    });

    test('sin reacciones: renderable == entrada, byTarget vacío', () {
      final all = <Message>[
        msg(externalId: 'm1'),
        msg(externalId: 'm2', ts: 1750),
      ];
      final folded = foldReactions(all);
      expect(folded.renderable, hasLength(2));
      expect(folded.byTarget, isEmpty);
    });
  });
}
