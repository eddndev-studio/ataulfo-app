import 'package:agentic/features/flows/data/dto/flow_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlowResp.fromJson', () {
    test('parsea el shape canónico del wire', () {
      final resp = FlowResp.fromJson(<String, dynamic>{
        'id': 'f1',
        'templateId': 't1',
        'name': 'Bienvenida',
        'isActive': true,
        'cooldownMs': 0,
        'usageLimit': 0,
        'excludesFlows': <dynamic>[],
        'version': 3,
        'createdAt': '2026-05-26T10:00:00Z',
        'updatedAt': '2026-05-26T10:00:00Z',
      });

      expect(resp.id, 'f1');
      expect(resp.templateId, 't1');
      expect(resp.name, 'Bienvenida');
      expect(resp.isActive, isTrue);
      expect(resp.version, 3);
    });

    test('campos requeridos ausentes → FormatException (fail-loud)', () {
      expect(
        () => FlowResp.fromJson(<String, dynamic>{
          'templateId': 't1',
          'name': 'Bienvenida',
          'isActive': true,
          'version': 1,
        }),
        throwsFormatException,
        reason: 'id ausente',
      );
      expect(
        () => FlowResp.fromJson(<String, dynamic>{
          'id': 'f1',
          'name': 'Bienvenida',
          'isActive': true,
          'version': 1,
        }),
        throwsFormatException,
        reason: 'templateId ausente',
      );
      expect(
        () => FlowResp.fromJson(<String, dynamic>{
          'id': 'f1',
          'templateId': 't1',
          'isActive': true,
          'version': 1,
        }),
        throwsFormatException,
        reason: 'name ausente',
      );
      expect(
        () => FlowResp.fromJson(<String, dynamic>{
          'id': 'f1',
          'templateId': 't1',
          'name': 'Bienvenida',
          'version': 1,
        }),
        throwsFormatException,
        reason: 'isActive ausente',
      );
      expect(
        () => FlowResp.fromJson(<String, dynamic>{
          'id': 'f1',
          'templateId': 't1',
          'name': 'Bienvenida',
          'isActive': true,
        }),
        throwsFormatException,
        reason: 'version ausente',
      );
    });

    test('tipos incorrectos → FormatException', () {
      expect(
        () => FlowResp.fromJson(<String, dynamic>{
          'id': 42, // debe ser string
          'templateId': 't1',
          'name': 'x',
          'isActive': true,
          'version': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => FlowResp.fromJson(<String, dynamic>{
          'id': 'f1',
          'templateId': 't1',
          'name': 'x',
          'isActive': 'sí', // debe ser bool
          'version': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => FlowResp.fromJson(<String, dynamic>{
          'id': 'f1',
          'templateId': 't1',
          'name': 'x',
          'isActive': true,
          'version': '1', // debe ser int
        }),
        throwsFormatException,
      );
    });
  });

  group('ListFlowsResp.fromJson', () {
    test('parsea {items:[...]} con varios flows', () {
      final resp = ListFlowsResp.fromJson(<String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{
            'id': 'f1',
            'templateId': 't1',
            'name': 'Bienvenida',
            'isActive': true,
            'version': 1,
          },
          <String, dynamic>{
            'id': 'f2',
            'templateId': 't1',
            'name': 'Despedida',
            'isActive': false,
            'version': 2,
          },
        ],
      });

      expect(resp.items, hasLength(2));
      expect(resp.items[0].id, 'f1');
      expect(resp.items[1].isActive, isFalse);
    });

    test('items ausente → FormatException', () {
      expect(
        () => ListFlowsResp.fromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });

    test('lista vacía es válida (template sin flows)', () {
      final resp = ListFlowsResp.fromJson(<String, dynamic>{
        'items': <dynamic>[],
      });
      expect(resp.items, isEmpty);
    });
  });
}
