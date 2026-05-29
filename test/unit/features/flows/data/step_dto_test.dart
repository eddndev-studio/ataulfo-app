import 'package:ataulfo/features/flows/data/dto/step_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StepResp.fromJson', () {
    test('parsea el shape canónico del wire', () {
      final resp = StepResp.fromJson(<String, dynamic>{
        'id': 's1',
        'flowId': 'f1',
        'type': 'TEXT',
        'order': 0,
        'content': 'Hola',
        'mediaRef': '',
        'metadata': <String, dynamic>{'foo': 'bar'},
        'delayMs': 1000,
        'jitterPct': 10,
        'aiOnly': false,
        'createdAt': '2026-05-26T10:00:00Z',
        'updatedAt': '2026-05-26T10:00:00Z',
      });
      expect(resp.id, 's1');
      expect(resp.flowId, 'f1');
      expect(resp.type, 'TEXT');
      expect(resp.order, 0);
      expect(resp.content, 'Hola');
      expect(resp.mediaRef, '');
      // metadata viene como Map del wire; el DTO la guarda como JSON
      // serializado para reconstruirlo después según necesidad.
      expect(resp.metadataJson, '{"foo":"bar"}');
      expect(resp.delayMs, 1000);
      expect(resp.jitterPct, 10);
      expect(resp.aiOnly, isFalse);
    });

    test('metadata ausente → "{}" (default jsonb del backend)', () {
      final resp = StepResp.fromJson(<String, dynamic>{
        'id': 's1',
        'flowId': 'f1',
        'type': 'TEXT',
        'order': 0,
        'content': 'x',
        'mediaRef': '',
        'delayMs': 0,
        'jitterPct': 0,
        'aiOnly': false,
      });
      expect(resp.metadataJson, '{}');
    });

    test('campos requeridos ausentes → FormatException', () {
      expect(
        () => StepResp.fromJson(<String, dynamic>{
          'flowId': 'f1',
          'type': 'TEXT',
          'order': 0,
          'content': '',
          'mediaRef': '',
          'delayMs': 0,
          'jitterPct': 0,
          'aiOnly': false,
        }),
        throwsFormatException,
        reason: 'id ausente',
      );
      expect(
        () => StepResp.fromJson(<String, dynamic>{
          'id': 's1',
          'flowId': 'f1',
          'type': 'TEXT',
          'order': 0,
          'content': '',
          'mediaRef': '',
          'delayMs': 0,
          'aiOnly': false,
        }),
        throwsFormatException,
        reason: 'jitterPct ausente',
      );
    });

    test('tipos incorrectos → FormatException', () {
      expect(
        () => StepResp.fromJson(<String, dynamic>{
          'id': 's1',
          'flowId': 'f1',
          'type': 'TEXT',
          'order': '0', // debe ser int
          'content': '',
          'mediaRef': '',
          'delayMs': 0,
          'jitterPct': 0,
          'aiOnly': false,
        }),
        throwsFormatException,
      );
    });
  });

  group('ListStepsResp.fromJson', () {
    test('parsea {items:[...]} con varios steps', () {
      final resp = ListStepsResp.fromJson(<String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{
            'id': 's1',
            'flowId': 'f1',
            'type': 'TEXT',
            'order': 0,
            'content': 'A',
            'mediaRef': '',
            'delayMs': 0,
            'jitterPct': 0,
            'aiOnly': false,
          },
          <String, dynamic>{
            'id': 's2',
            'flowId': 'f1',
            'type': 'IMAGE',
            'order': 1,
            'content': '',
            'mediaRef': 'https://example.com/img.png',
            'delayMs': 500,
            'jitterPct': 5,
            'aiOnly': true,
          },
        ],
      });
      expect(resp.items, hasLength(2));
      expect(resp.items[0].type, 'TEXT');
      expect(resp.items[1].mediaRef, 'https://example.com/img.png');
      expect(resp.items[1].aiOnly, isTrue);
    });

    test('lista vacía es válida', () {
      final resp = ListStepsResp.fromJson(<String, dynamic>{
        'items': <dynamic>[],
      });
      expect(resp.items, isEmpty);
    });

    test('items ausente → FormatException', () {
      expect(
        () => ListStepsResp.fromJson(<String, dynamic>{}),
        throwsFormatException,
      );
    });
  });
}
