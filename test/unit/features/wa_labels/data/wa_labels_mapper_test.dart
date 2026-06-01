import 'package:ataulfo/features/wa_labels/data/dto/wa_assoc_dto.dart';
import 'package:ataulfo/features/wa_labels/data/dto/wa_label_dto.dart';
import 'package:ataulfo/features/wa_labels/data/dto/wa_label_event_dto.dart';
import 'package:ataulfo/features/wa_labels/data/dto/wa_mapping_dto.dart';
import 'package:ataulfo/features/wa_labels/data/mappers/wa_labels_mapper.dart';
import 'package:ataulfo/features/wa_labels/domain/entities/wa_label_live_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('catálogo / asociaciones / mapeo', () {
    test('catalogToLabels preserva orden e incluye tombstones', () {
      final labels = WaLabelsMapper.catalogToLabels(
        WaCatalogResp.fromJson(<String, dynamic>{
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
        }),
      );
      expect(labels, hasLength(2));
      expect(labels[0].waLabelId, '1000');
      expect(labels[0].color, 3);
      expect(labels[1].deleted, isTrue);
    });

    test('chatAssocToEntities + msgAssocToEntities', () {
      final chats = WaLabelsMapper.chatAssocToEntities(
        WaChatAssocListResp.fromJson(<String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'chatLid': 'c1',
              'waLabelId': '1000',
              'labeled': true,
            },
          ],
        }),
      );
      expect(chats.single.chatLid, 'c1');

      final msgs = WaLabelsMapper.msgAssocToEntities(
        WaMsgAssocListResp.fromJson(<String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{
              'chatLid': 'c1',
              'messageId': 'wamid.1',
              'waLabelId': '1000',
              'labeled': false,
            },
          ],
        }),
      );
      expect(msgs.single.messageId, 'wamid.1');
      expect(msgs.single.labeled, isFalse);
    });

    test('mappingsToEntities + single', () {
      final ms = WaLabelsMapper.mappingsToEntities(
        WaMappingListResp.fromJson(<String, dynamic>{
          'items': <Map<String, dynamic>>[
            <String, dynamic>{'waLabelId': '1000', 'labelId': 'uuid-vip'},
          ],
        }),
      );
      expect(ms.single.labelId, 'uuid-vip');

      final one = WaLabelsMapper.mappingToEntity(
        WaMappingResp.fromJson(<String, dynamic>{
          'waLabelId': '1000',
          'labelId': 'uuid-vip',
        }),
      );
      expect(one.waLabelId, '1000');
    });
  });

  group('eventToLive (frame SSE → evento de dominio)', () {
    WaLabelEventResp resp(Map<String, dynamic> over) => WaLabelEventResp.fromJson(
      <String, dynamic>{
        'botId': 'bot-1',
        'waLabelId': '1000',
        'color': 3,
        'labeled': false,
        'at': '2026-05-31T12:00:00Z',
        ...over,
      },
    );

    test('EDITED → WaLabelCatalogChanged(removed:false)', () {
      final ev = WaLabelsMapper.eventToLive(
        resp(<String, dynamic>{'kind': 'EDITED', 'name': 'VIP'}),
      );
      expect(
        ev,
        const WaLabelCatalogChanged(
          waLabelId: '1000',
          name: 'VIP',
          color: 3,
          removed: false,
        ),
      );
    });

    test('REMOVED → WaLabelCatalogChanged(removed:true), name vacío', () {
      final ev = WaLabelsMapper.eventToLive(resp(<String, dynamic>{'kind': 'REMOVED'}));
      expect(
        ev,
        const WaLabelCatalogChanged(
          waLabelId: '1000',
          name: '',
          color: 3,
          removed: true,
        ),
      );
    });

    test('CHAT → WaChatLabelChanged', () {
      final ev = WaLabelsMapper.eventToLive(
        resp(<String, dynamic>{'kind': 'CHAT', 'chatLid': 'c1', 'labeled': true}),
      );
      expect(
        ev,
        const WaChatLabelChanged(
          waLabelId: '1000',
          chatLid: 'c1',
          color: 3,
          labeled: true,
        ),
      );
    });

    test('MESSAGE → WaMessageLabelChanged', () {
      final ev = WaLabelsMapper.eventToLive(
        resp(<String, dynamic>{
          'kind': 'MESSAGE',
          'chatLid': 'c1',
          'messageId': 'wamid.1',
        }),
      );
      expect(
        ev,
        const WaMessageLabelChanged(
          waLabelId: '1000',
          chatLid: 'c1',
          messageId: 'wamid.1',
          color: 3,
          labeled: false,
        ),
      );
    });

    test('kind desconocido → ArgumentError (fail-loud; el datasource lo omite)', () {
      expect(
        () => WaLabelsMapper.eventToLive(resp(<String, dynamic>{'kind': 'ARCHIVED'})),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('CHAT sin chatLid → FormatException', () {
      expect(
        () => WaLabelsMapper.eventToLive(resp(<String, dynamic>{'kind': 'CHAT'})),
        throwsA(isA<FormatException>()),
      );
    });

    test('MESSAGE sin messageId → FormatException', () {
      expect(
        () => WaLabelsMapper.eventToLive(
          resp(<String, dynamic>{'kind': 'MESSAGE', 'chatLid': 'c1'}),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
