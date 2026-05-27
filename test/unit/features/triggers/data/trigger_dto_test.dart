import 'package:agentic/features/triggers/data/dto/trigger_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TriggerResp.fromJson', () {
    test('TEXT trigger con todos los campos del wire', () {
      final r = TriggerResp.fromJson(<String, dynamic>{
        'id': 't1',
        'templateId': 'tpl1',
        'flowId': 'f1',
        'type': 'TEXT',
        'matchType': 'CONTAINS',
        'keyword': 'hola',
        'scope': 'BOTH',
        'isActive': true,
        'createdAt': '2026-05-01T12:00:00Z',
        'updatedAt': '2026-05-02T08:30:00Z',
      });
      expect(r.id, 't1');
      expect(r.templateId, 'tpl1');
      expect(r.flowId, 'f1');
      expect(r.type, 'TEXT');
      expect(r.matchType, 'CONTAINS');
      expect(r.keyword, 'hola');
      expect(r.labelId, '');
      expect(r.labelAction, isNull);
      expect(r.scope, 'BOTH');
      expect(r.isActive, isTrue);
      expect(r.createdAt, DateTime.utc(2026, 5, 1, 12));
      expect(r.updatedAt, DateTime.utc(2026, 5, 2, 8, 30));
    });

    test('LABEL trigger sin matchType/keyword (campos omitempty del wire)', () {
      final r = TriggerResp.fromJson(<String, dynamic>{
        'id': 't2',
        'templateId': 'tpl1',
        'flowId': 'f1',
        'type': 'LABEL',
        'labelId': 'lbl_vip',
        'labelAction': 'ADD',
        'scope': 'BOTH',
        'isActive': false,
        'createdAt': '2026-05-01T12:00:00Z',
        'updatedAt': '2026-05-01T12:00:00Z',
      });
      expect(r.type, 'LABEL');
      expect(r.matchType, isNull);
      expect(r.keyword, '');
      expect(r.labelId, 'lbl_vip');
      expect(r.labelAction, 'ADD');
      expect(r.isActive, isFalse);
    });

    test('campos requeridos faltantes lanzan FormatException', () {
      // sin 'id'
      expect(
        () => TriggerResp.fromJson(<String, dynamic>{
          'templateId': 'tpl1',
          'flowId': 'f1',
          'type': 'TEXT',
          'scope': 'BOTH',
          'isActive': true,
          'createdAt': '2026-05-01T12:00:00Z',
          'updatedAt': '2026-05-01T12:00:00Z',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('createdAt no parseable lanza FormatException', () {
      expect(
        () => TriggerResp.fromJson(<String, dynamic>{
          'id': 't1',
          'templateId': 'tpl1',
          'flowId': 'f1',
          'type': 'TEXT',
          'matchType': 'EXACT',
          'keyword': 'x',
          'scope': 'BOTH',
          'isActive': true,
          'createdAt': 'no-es-fecha',
          'updatedAt': '2026-05-01T12:00:00Z',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('ListTriggersResp.fromJson', () {
    test('parsea {items:[...]}', () {
      final r = ListTriggersResp.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 't1',
            'templateId': 'tpl1',
            'flowId': 'f1',
            'type': 'TEXT',
            'matchType': 'EXACT',
            'keyword': 'menu',
            'scope': 'INCOMING',
            'isActive': true,
            'createdAt': '2026-05-01T12:00:00Z',
            'updatedAt': '2026-05-01T12:00:00Z',
          },
          <String, dynamic>{
            'id': 't2',
            'templateId': 'tpl1',
            'flowId': 'f2',
            'type': 'LABEL',
            'labelId': 'vip',
            'labelAction': 'ADD',
            'scope': 'BOTH',
            'isActive': true,
            'createdAt': '2026-05-01T12:00:00Z',
            'updatedAt': '2026-05-01T12:00:00Z',
          },
        ],
      });
      expect(r.items, hasLength(2));
      expect(r.items[0].id, 't1');
      expect(r.items[1].id, 't2');
    });

    test('items vacío es válido (sin disparadores en la template)', () {
      final r = ListTriggersResp.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[],
      });
      expect(r.items, isEmpty);
    });

    test('items ausente lanza FormatException', () {
      expect(
        () => ListTriggersResp.fromJson(<String, dynamic>{}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
