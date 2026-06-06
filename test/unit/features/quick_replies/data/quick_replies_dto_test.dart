import 'package:ataulfo/features/quick_replies/data/dto/quick_reply_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuickReplyResp.fromJson', () {
    test('lee los 4 campos e IGNORA keywords/count/associatedLabelIds', () {
      final r = QuickReplyResp.fromJson(<String, dynamic>{
        'waQuickReplyId': '61',
        'shortcut': 'saludo',
        'message': 'Hola',
        'keywords': <String>['hi', 'hello'],
        'count': 7,
        'deleted': false,
        'associatedLabelIds': <String>['1000'],
      });
      expect(r.waQuickReplyId, '61');
      expect(r.shortcut, 'saludo');
      expect(r.message, 'Hola');
      expect(r.deleted, isFalse);
    });

    test('tombstone: deleted true con shortcut/message vacíos', () {
      final r = QuickReplyResp.fromJson(<String, dynamic>{
        'waQuickReplyId': '61',
        'shortcut': '',
        'message': '',
        'keywords': <String>[],
        'count': 0,
        'deleted': true,
        'associatedLabelIds': <String>[],
      });
      expect(r.deleted, isTrue);
    });

    test('campo requerido faltante o de tipo incorrecto → FormatException', () {
      expect(
        () => QuickReplyResp.fromJson(<String, dynamic>{
          'waQuickReplyId': '61',
          'shortcut': 'x',
          'message': 'y',
          // deleted ausente
        }),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => QuickReplyResp.fromJson(<String, dynamic>{
          'waQuickReplyId': 61, // int, no String
          'shortcut': 'x',
          'message': 'y',
          'deleted': false,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('QuickRepliesCatalogResp.fromJson', () {
    test('{items:[...]} → lista en orden', () {
      final resp = QuickRepliesCatalogResp.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'waQuickReplyId': '1',
            'shortcut': 'a',
            'message': 'A',
            'keywords': <String>[],
            'count': 0,
            'deleted': false,
            'associatedLabelIds': <String>[],
          },
          <String, dynamic>{
            'waQuickReplyId': '2',
            'shortcut': 'b',
            'message': 'B',
            'keywords': <String>[],
            'count': 0,
            'deleted': true,
            'associatedLabelIds': <String>[],
          },
        ],
      });
      expect(resp.items, hasLength(2));
      expect(resp.items[0].waQuickReplyId, '1');
      expect(resp.items[1].deleted, isTrue);
    });

    test('items vacío → lista vacía', () {
      final resp = QuickRepliesCatalogResp.fromJson(<String, dynamic>{
        'items': <dynamic>[],
      });
      expect(resp.items, isEmpty);
    });

    test('sin items array → FormatException', () {
      expect(
        () => QuickRepliesCatalogResp.fromJson(<String, dynamic>{'foo': 'bar'}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
