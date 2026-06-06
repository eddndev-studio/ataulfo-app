import 'package:ataulfo/features/quick_replies/domain/entities/quick_reply.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuickReply', () {
    test('dos instancias con la misma data son iguales', () {
      const a = QuickReply(
        waQuickReplyId: '61',
        shortcut: 'saludo',
        message: 'Hola, ¿en qué te ayudo?',
        deleted: false,
      );
      const b = QuickReply(
        waQuickReplyId: '61',
        shortcut: 'saludo',
        message: 'Hola, ¿en qué te ayudo?',
        deleted: false,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('difiere por cualquier campo', () {
      const base = QuickReply(
        waQuickReplyId: '61',
        shortcut: 'saludo',
        message: 'Hola',
        deleted: false,
      );
      expect(
        base,
        isNot(
          const QuickReply(
            waQuickReplyId: '62',
            shortcut: 'saludo',
            message: 'Hola',
            deleted: false,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const QuickReply(
            waQuickReplyId: '61',
            shortcut: 'otro',
            message: 'Hola',
            deleted: false,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const QuickReply(
            waQuickReplyId: '61',
            shortcut: 'saludo',
            message: 'Adiós',
            deleted: false,
          ),
        ),
      );
      expect(
        base,
        isNot(
          const QuickReply(
            waQuickReplyId: '61',
            shortcut: 'saludo',
            message: 'Hola',
            deleted: true,
          ),
        ),
      );
    });
  });
}
