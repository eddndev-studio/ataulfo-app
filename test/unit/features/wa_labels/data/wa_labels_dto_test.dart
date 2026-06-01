import 'package:ataulfo/features/wa_labels/data/dto/wa_assoc_dto.dart';
import 'package:ataulfo/features/wa_labels/data/dto/wa_label_dto.dart';
import 'package:ataulfo/features/wa_labels/data/dto/wa_mapping_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WaLabelResp.fromJson', () {
    test('etiqueta activa con todos los campos', () {
      final r = WaLabelResp.fromJson(<String, dynamic>{
        'waLabelId': '1000',
        'name': 'Cliente VIP',
        'color': 3,
        'deleted': false,
      });
      expect(r.waLabelId, '1000');
      expect(r.name, 'Cliente VIP');
      expect(r.color, 3);
      expect(r.deleted, isFalse);
    });

    test('color 0 es válido (no se confunde con ausente)', () {
      final r = WaLabelResp.fromJson(<String, dynamic>{
        'waLabelId': '1001',
        'name': 'Cero',
        'color': 0,
        'deleted': false,
      });
      expect(r.color, 0);
    });

    test('tombstone con name vacío', () {
      final r = WaLabelResp.fromJson(<String, dynamic>{
        'waLabelId': '1000',
        'name': '',
        'color': 7,
        'deleted': true,
      });
      expect(r.deleted, isTrue);
      expect(r.name, '');
    });

    test('campo requerido ausente → FormatException', () {
      expect(
        () => WaLabelResp.fromJson(<String, dynamic>{
          'waLabelId': '1000',
          'name': 'x',
          'deleted': false,
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('tipo incorrecto (color string) → FormatException', () {
      expect(
        () => WaLabelResp.fromJson(<String, dynamic>{
          'waLabelId': '1000',
          'name': 'x',
          'color': '3',
          'deleted': false,
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('WaCatalogResp.fromJson', () {
    test('lista con items', () {
      final r = WaCatalogResp.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'waLabelId': '1000',
            'name': 'VIP',
            'color': 3,
            'deleted': false,
          },
          <String, dynamic>{
            'waLabelId': '1001',
            'name': '',
            'color': 0,
            'deleted': true,
          },
        ],
      });
      expect(r.items, hasLength(2));
      expect(r.items[1].deleted, isTrue);
    });

    test('lista vacía es válida', () {
      final r = WaCatalogResp.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[],
      });
      expect(r.items, isEmpty);
    });

    test('sin items array → FormatException', () {
      expect(
        () => WaCatalogResp.fromJson(<String, dynamic>{'foo': 'bar'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('WaChatAssocResp / WaChatAssocListResp', () {
    test('parsea chatLid + waLabelId + labeled', () {
      final r = WaChatAssocListResp.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'chatLid': 'c1',
            'waLabelId': '1000',
            'labeled': true,
          },
          <String, dynamic>{
            'chatLid': 'c1',
            'waLabelId': '1001',
            'labeled': false,
          },
        ],
      });
      expect(r.items, hasLength(2));
      expect(r.items[0].chatLid, 'c1');
      expect(r.items[1].labeled, isFalse);
    });
  });

  group('WaMsgAssocResp / WaMsgAssocListResp', () {
    test('parsea chatLid + messageId + waLabelId + labeled', () {
      final r = WaMsgAssocListResp.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'chatLid': 'c1',
            'messageId': 'wamid.1',
            'waLabelId': '1000',
            'labeled': true,
          },
        ],
      });
      expect(r.items, hasLength(1));
      expect(r.items[0].messageId, 'wamid.1');
    });
  });

  group('WaMappingResp / WaMappingListResp', () {
    test('parsea waLabelId + labelId', () {
      final r = WaMappingListResp.fromJson(<String, dynamic>{
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'waLabelId': '1000', 'labelId': 'uuid-vip'},
        ],
      });
      expect(r.items, hasLength(1));
      expect(r.items[0].waLabelId, '1000');
      expect(r.items[0].labelId, 'uuid-vip');
    });

    test('single mappingResp', () {
      final r = WaMappingResp.fromJson(<String, dynamic>{
        'waLabelId': '1000',
        'labelId': 'uuid-vip',
      });
      expect(r.labelId, 'uuid-vip');
    });
  });
}
