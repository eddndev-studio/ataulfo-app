import 'package:ataulfo/features/labels/data/dto/label_dto.dart';
import 'package:ataulfo/features/labels/data/mappers/labels_mapper.dart';
import 'package:ataulfo/features/labels/domain/entities/label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Label value-equality', () {
    test('iguala por campos', () {
      const a = Label(
        id: 'u1',
        name: 'VIP',
        color: '#34B7F1',
        description: 'clientes top',
      );
      const b = Label(
        id: 'u1',
        name: 'VIP',
        color: '#34B7F1',
        description: 'clientes top',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const Label(id: 'u2', name: 'VIP', color: '#34B7F1', description: 'clientes top')));
    });
  });

  group('LabelResp.fromJson', () {
    test('parsea id/name/color(hex)/description', () {
      final r = LabelResp.fromJson(<String, dynamic>{
        'id': 'u1',
        'name': 'VIP',
        'color': '#34B7F1',
        'description': 'clientes top',
        'createdAt': '2026-05-01T12:00:00Z',
        'updatedAt': '2026-05-01T12:00:00Z',
      });
      expect(r.id, 'u1');
      expect(r.name, 'VIP');
      expect(r.color, '#34B7F1');
      expect(r.description, 'clientes top');
    });

    test('description vacía es válida', () {
      final r = LabelResp.fromJson(<String, dynamic>{
        'id': 'u1',
        'name': 'VIP',
        'color': '#34B7F1',
        'description': '',
      });
      expect(r.description, '');
    });

    test('color string ausente → FormatException', () {
      expect(
        () => LabelResp.fromJson(<String, dynamic>{
          'id': 'u1',
          'name': 'VIP',
          'description': '',
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('LabelListResp + mapper', () {
    test('listToLabels preserva orden', () {
      final ls = LabelsMapper.listToLabels(
        LabelListResp.fromJson(<String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'u1',
              'name': 'VIP',
              'color': '#34B7F1',
              'description': '',
            },
            <String, dynamic>{
              'id': 'u2',
              'name': 'Spam',
              'color': '#FF0000',
              'description': 'no responder',
            },
          ],
        }),
      );
      expect(ls, hasLength(2));
      expect(ls[0], const Label(id: 'u1', name: 'VIP', color: '#34B7F1', description: ''));
      expect(ls[1].name, 'Spam');
    });

    test('sin items array → FormatException', () {
      expect(
        () => LabelListResp.fromJson(<String, dynamic>{'foo': 1}),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
